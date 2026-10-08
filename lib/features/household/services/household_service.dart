import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model.dart';
import '../models/shopping_list_model.dart';
import '../models/expense_model.dart';
import '../models/meal_plan_model.dart';
import '../../../services/notification_service.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/services/task_service.dart';

class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _mealsCollection => _firestore.collection('meals');

  // ==========================================
  // MEALS
  // ==========================================

  Stream<List<MealModel>> getMeals() {
    return _mealsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MealModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> createMeal(MealModel meal) async {
    await _mealsCollection.add(meal.toMap());
  }

  Future<void> updateMeal(MealModel meal) async {
    await _mealsCollection.doc(meal.id).update(meal.toMap());
  }

  Future<void> deleteMeal(String mealId) async {
    await _mealsCollection.doc(mealId).delete();
  }

  // ==========================================
  // MEAL HISTORY (Phase E)
  // ==========================================

  CollectionReference _mealHistoryCollection(String familyId) => 
      _firestore.collection('families').doc(familyId).collection('meal_history');

  Future<void> recordMealHistory(String familyId, List<MealModel> meals) async {
    final batch = _firestore.batch();
    for (var meal in meals) {
      final docRef = _mealHistoryCollection(familyId).doc();
      batch.set(docRef, {
        'mealId': meal.id,
        'mealName': meal.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<List<String>> getRecentMealHistoryIds(String familyId, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _mealHistoryCollection(familyId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc['mealId'] as String).toList());
  }

  // ==========================================
  // MEAL PLANS (Phase G)
  // ==========================================

  CollectionReference _mealPlansCollection(String familyId) => 
      _firestore.collection('families').doc(familyId).collection('meal_plans');

  Future<void> createMealPlan(MealPlanModel plan) async {
    await _mealPlansCollection(plan.familyId).add(plan.toMap());
  }

  Stream<List<MealPlanModel>> getMealPlans(String familyId, DateTime startDate, DateTime endDate) {
    return _mealPlansCollection(familyId)
        .where('targetDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('targetDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('targetDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MealPlanModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addMealToTodayPlan(String familyId, MealModel meal, String userId) async {
    final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final endOfDay = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);
    
    final query = await _mealPlansCollection(familyId)
        .where('targetDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('targetDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    if (query.docs.isNotEmpty) {
      // Có plan hôm nay, thêm mealId
      final docId = query.docs.first.id;
      final data = query.docs.first.data() as Map<String, dynamic>;
      final List<String> currentMeals = List<String>.from(data['mealIds'] ?? []);
      final currentCost = (data['estimatedTotalCost'] ?? 0).toDouble();

      if (!currentMeals.contains(meal.id)) {
        currentMeals.add(meal.id);
        await _mealPlansCollection(familyId).doc(docId).update({
          'mealIds': currentMeals,
          'estimatedTotalCost': currentCost + meal.estimatedCost,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Chưa có plan, tạo mới
      final newPlan = MealPlanModel(
        id: '',
        familyId: familyId,
        targetDate: DateTime.now(),
        mealIds: [meal.id],
        estimatedTotalCost: meal.estimatedCost,
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await createMealPlan(newPlan);
    }
  }

  Future<void> updateMealFeedback(String familyId, String planId, String mealId, int rating, String note) async {
    final docRef = _mealPlansCollection(familyId).doc(planId);
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      final ratings = Map<String, int>.from(data['mealRatings'] ?? {});
      final notes = Map<String, String>.from(data['mealNotes'] ?? {});
      
      ratings[mealId] = rating;
      notes[mealId] = note;
      
      transaction.update(docRef, {
        'mealRatings': ratings,
        'mealNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ==========================================
  // SHOPPING LISTS & EXPENSES (Phase H, I, J)
  // ==========================================

  CollectionReference _shoppingListsCollection(String familyId) => 
      _firestore.collection('families').doc(familyId).collection('shopping_lists');

  CollectionReference _expensesCollection(String familyId) => 
      _firestore.collection('families').doc(familyId).collection('expenses');

  Future<void> createShoppingList(ShoppingListModel list) async {
    await _shoppingListsCollection(list.familyId).add(list.toMap());
    
    // Phase I & O: Assign Task & Notification
    if (list.assignedTo.isNotEmpty) {
      // Gửi Notification
      try {
        final userDoc = await _firestore.collection('users').doc(list.assignedTo).get();
        final fcmToken = userDoc.data()?['fcmToken'];
        if (fcmToken != null) {
          await NotificationService.sendPushNotification(
            fcmToken,
            'Nhiệm vụ đi chợ',
            'Bạn được giao đi chợ với dự toán ${list.estimatedTotal}đ',
            type: 'shopping',
          );
        }
      } catch (e) {
        // Ignore
      }

      // Tạo Task (Việc nhà)
      try {
        final taskService = TaskService();
        final task = TaskModel(
          id: '',
          title: 'Đi chợ ngày ${list.targetDate.day}/${list.targetDate.month}',
          description: 'Dự toán: ${list.estimatedTotal}đ. Hãy ghi lại chi tiêu sau khi đi chợ xong.',
          createdBy: list.assignedBy,
          assignedTo: list.assignedTo,
          status: 'todo',
          priority: 'high',
          category: 'shopping',
          dueDate: list.targetDate,
          points: 5, // Điểm thưởng
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await taskService.createTask(task);
      } catch (e) {
        // Ignore
      }
    }
  }

  Stream<List<ShoppingListModel>> getActiveShoppingLists(String familyId) {
    // Dùng query đơn giản để tránh cần Composite Index
    return _shoppingListsCollection(familyId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShoppingListModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList()
          ..retainWhere((list) => list.status != 'completed'));
  }

  /// Lấy shopping list được tạo hôm nay
  Stream<List<ShoppingListModel>> getTodayShoppingLists(String familyId) {
    final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final endOfDay = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);
    return _shoppingListsCollection(familyId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShoppingListModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> updateShoppingList(ShoppingListModel list) async {
    await _shoppingListsCollection(list.familyId).doc(list.id).update(list.toMap());
  }

  Future<void> recordExpense(ExpenseModel expense, ShoppingListModel list) async {
    final batch = _firestore.batch();
    
    // Lưu expense
    final expenseRef = _expensesCollection(expense.familyId).doc();
    batch.set(expenseRef, expense.toMap());
    
    // Cập nhật trạng thái shopping list -> completed
    final listRef = _shoppingListsCollection(list.familyId).doc(list.id);
    batch.update(listRef, {
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<ExpenseModel>> getWeeklyExpenses(String familyId, DateTime startOfWeek, DateTime endOfWeek) {
    return _expensesCollection(familyId)
        .where('purchasedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('purchasedAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}
