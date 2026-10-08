import 'dart:math';
import '../models/meal_model.dart';

enum MealGeneratorMode {
  normal,
  fast,
  budget,
  lazy,
  weekend
}

class MealGeneratorService {
  
  /// Tự động sinh một bữa ăn (1 canh, 1-2 mặn tùy vào cấu hình)
  /// Lọc bỏ các món đã ăn trong [avoidRepeatDays]
  static List<MealModel> generateMealPlan({
    required List<MealModel> allMeals,
    required List<MealModel> history,
    required MealGeneratorMode mode,
    double? budgetLimit,
    int avoidRepeatDays = 7,
  }) {
    if (allMeals.isEmpty) return [];

    // Lọc bỏ món không active
    var available = allMeals.where((m) => m.isActive).toList();

    // Lọc theo history (Phase E)
    final now = DateTime.now();
    final recentHistory = history.where((h) {
      final diff = now.difference(h.createdAt).inDays;
      return diff <= avoidRepeatDays;
    }).map((e) => e.id).toSet();

    available = available.where((m) => !recentHistory.contains(m.id)).toList();

    // Nếu lọc xong mà hết món, thì đành phải lấy lại lịch sử cũ (fallback)
    if (available.isEmpty) {
      available = allMeals.where((m) => m.isActive).toList();
    }

    // Filter theo Mode
    switch (mode) {
      case MealGeneratorMode.fast:
        available = available.where((m) => (m.prepTime + m.cookTime) <= 30).toList();
        break;
      case MealGeneratorMode.budget:
        final maxCost = budgetLimit != null ? (budgetLimit / 2) : 70000.0;
        available = available.where((m) => m.estimatedCost <= maxCost).toList();
        break;
      case MealGeneratorMode.lazy:
        available = available.where((m) => m.difficulty == 'easy' && (m.prepTime + m.cookTime) <= 45).toList();
        break;
      case MealGeneratorMode.weekend:
        // Cuối tuần có thể nấu món lâu hơn hoặc ngon hơn
        final weekendMeals = available.where((m) => m.tags.contains('weekend') || m.difficulty != 'easy' || m.estimatedCost >= 100000).toList();
        if (weekendMeals.isNotEmpty) available = weekendMeals;
        break;
      case MealGeneratorMode.normal:
      default:
        break;
    }
    
    // Lưu ý: Nếu filter theo mode xong bị rỗng, ta KHÔNG fallback về toàn bộ danh sách
    // để tránh việc user chọn "Tiết kiệm" nhưng lại ra món "Đắt tiền".
    // Chỉ fallback nếu danh sách rỗng từ trước khi filter mode (do lịch sử quá dày).

    // Tách món mặn, món canh, món rau
    final mainDishes = available.where((m) => m.mealType == 'main').toList();
    final soupDishes = available.where((m) => m.mealType == 'soup').toList();
    final vegDishes = available.where((m) => m.mealType == 'vegetable').toList();

    final random = Random();
    List<MealModel> selectedMeals = [];

    // Mặc định chọn 1 mặn
    if (mainDishes.isNotEmpty) {
      selectedMeals.add(mainDishes[random.nextInt(mainDishes.length)]);
    }

    // Nếu ngân sách cho phép hoặc chế độ bình thường, thêm 1 canh hoặc rau
    if (soupDishes.isNotEmpty && vegDishes.isNotEmpty) {
      // 50% canh, 50% rau
      if (random.nextBool()) {
        selectedMeals.add(soupDishes[random.nextInt(soupDishes.length)]);
      } else {
        selectedMeals.add(vegDishes[random.nextInt(vegDishes.length)]);
      }
    } else if (soupDishes.isNotEmpty) {
      selectedMeals.add(soupDishes[random.nextInt(soupDishes.length)]);
    } else if (vegDishes.isNotEmpty) {
      selectedMeals.add(vegDishes[random.nextInt(vegDishes.length)]);
    }

    return selectedMeals;
  }
}
