import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlanModel {
  final String id;
  final String familyId;
  final DateTime targetDate;
  final List<String> mealIds; // ID các món ăn trong ngày
  final Map<String, int> mealRatings; // Đánh giá theo ID món (1-5 sao)
  final Map<String, String> mealNotes; // Ghi chú theo ID món
  final double estimatedTotalCost;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPlanModel({
    required this.id,
    required this.familyId,
    required this.targetDate,
    this.mealIds = const [],
    this.mealRatings = const {},
    this.mealNotes = const {},
    this.estimatedTotalCost = 0.0,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  MealPlanModel copyWith({
    String? id,
    String? familyId,
    DateTime? targetDate,
    List<String>? mealIds,
    Map<String, int>? mealRatings,
    Map<String, String>? mealNotes,
    double? estimatedTotalCost,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealPlanModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      targetDate: targetDate ?? this.targetDate,
      mealIds: mealIds ?? this.mealIds,
      mealRatings: mealRatings ?? this.mealRatings,
      mealNotes: mealNotes ?? this.mealNotes,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'targetDate': Timestamp.fromDate(targetDate),
      'mealIds': mealIds,
      'mealRatings': mealRatings,
      'mealNotes': mealNotes,
      'estimatedTotalCost': estimatedTotalCost,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MealPlanModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MealPlanModel(
      id: documentId,
      familyId: map['familyId'] ?? '',
      targetDate: map['targetDate'] != null ? (map['targetDate'] as Timestamp).toDate() : DateTime.now(),
      mealIds: List<String>.from(map['mealIds'] ?? []),
      mealRatings: Map<String, int>.from(map['mealRatings'] ?? {}),
      mealNotes: Map<String, String>.from(map['mealNotes'] ?? {}),
      estimatedTotalCost: (map['estimatedTotalCost'] ?? 0).toDouble(),
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
