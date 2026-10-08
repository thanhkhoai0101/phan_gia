import 'package:cloud_firestore/cloud_firestore.dart';
import 'shopping_list_model.dart';

class ExpenseModel {
  final String id;
  final String familyId;
  final String shoppingListId;
  final String createdBy; // Người nhập (thường là assignedTo của shopping list)
  
  final double estimatedAmount;
  final double actualAmount;
  final double difference; // actualAmount - estimatedAmount
  
  final List<ShoppingItemModel> items;
  final String? receiptImageUrl;
  final String category; // grocery, utility, etc.
  
  final DateTime purchasedAt;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.familyId,
    required this.shoppingListId,
    required this.createdBy,
    required this.estimatedAmount,
    required this.actualAmount,
    required this.difference,
    this.items = const [],
    this.receiptImageUrl,
    this.category = 'grocery',
    required this.purchasedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'shoppingListId': shoppingListId,
      'createdBy': createdBy,
      'estimatedAmount': estimatedAmount,
      'actualAmount': actualAmount,
      'difference': difference,
      'items': items.map((x) => x.toMap()).toList(),
      'receiptImageUrl': receiptImageUrl,
      'category': category,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      // Các trường dùng để query thống kê tuần/tháng
      'year': purchasedAt.year,
      'month': purchasedAt.month,
      'week': _weekOfYear(purchasedAt),
      'dayOfWeek': purchasedAt.weekday, // 1=Mon, 7=Sun
    };
  }

  static int _weekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays;
    return ((dayOfYear + startOfYear.weekday - 1) / 7).ceil();
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ExpenseModel(
      id: documentId,
      familyId: map['familyId'] ?? '',
      shoppingListId: map['shoppingListId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      estimatedAmount: (map['estimatedAmount'] ?? 0).toDouble(),
      actualAmount: (map['actualAmount'] ?? 0).toDouble(),
      difference: (map['difference'] ?? 0).toDouble(),
      items: List<ShoppingItemModel>.from((map['items'] ?? []).map((x) => ShoppingItemModel.fromMap(x))),
      receiptImageUrl: map['receiptImageUrl'],
      category: map['category'] ?? 'grocery',
      purchasedAt: map['purchasedAt'] != null ? (map['purchasedAt'] as Timestamp).toDate() : DateTime.now(),
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
