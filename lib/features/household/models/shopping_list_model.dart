import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_model.dart';

class ShoppingItemModel {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool isChecked;
  final double? actualPrice; // Giá thực tế nếu nhập chi tiết

  ShoppingItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.isChecked = false,
    this.actualPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isChecked': isChecked,
      'actualPrice': actualPrice,
    };
  }

  factory ShoppingItemModel.fromMap(Map<String, dynamic> map) {
    return ShoppingItemModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      isChecked: map['isChecked'] ?? false,
      actualPrice: map['actualPrice'] != null ? (map['actualPrice'] as num).toDouble() : null,
    );
  }

  ShoppingItemModel copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    bool? isChecked,
    double? actualPrice,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      actualPrice: actualPrice ?? this.actualPrice,
    );
  }
}

class ShoppingListModel {
  final String id;
  final String familyId;
  final List<ShoppingItemModel> items;
  final String assignedTo; // uid của người đi chợ
  final String assignedBy;
  final String status; // 'pending', 'in_progress', 'completed'
  final double estimatedTotal;
  final DateTime targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? relatedMealPlanId;

  ShoppingListModel({
    required this.id,
    required this.familyId,
    required this.items,
    this.assignedTo = '',
    this.assignedBy = '',
    this.status = 'pending',
    this.estimatedTotal = 0.0,
    required this.targetDate,
    required this.createdAt,
    required this.updatedAt,
    this.relatedMealPlanId,
  });

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'items': items.map((x) => x.toMap()).toList(),
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'status': status,
      'estimatedTotal': estimatedTotal,
      'targetDate': Timestamp.fromDate(targetDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'relatedMealPlanId': relatedMealPlanId,
    };
  }

  factory ShoppingListModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ShoppingListModel(
      id: documentId,
      familyId: map['familyId'] ?? '',
      items: List<ShoppingItemModel>.from((map['items'] ?? []).map((x) => ShoppingItemModel.fromMap(x))),
      assignedTo: map['assignedTo'] ?? '',
      assignedBy: map['assignedBy'] ?? '',
      status: map['status'] ?? 'pending',
      estimatedTotal: (map['estimatedTotal'] ?? 0).toDouble(),
      targetDate: map['targetDate'] != null ? (map['targetDate'] as Timestamp).toDate() : DateTime.now(),
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      relatedMealPlanId: map['relatedMealPlanId'],
    );
  }

  ShoppingListModel copyWith({
    String? id,
    String? familyId,
    List<ShoppingItemModel>? items,
    String? assignedTo,
    String? assignedBy,
    String? status,
    double? estimatedTotal,
    DateTime? targetDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? relatedMealPlanId,
  }) {
    return ShoppingListModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      items: items ?? this.items,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      status: status ?? this.status,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      relatedMealPlanId: relatedMealPlanId ?? this.relatedMealPlanId,
    );
  }
}
