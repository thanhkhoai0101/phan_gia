import 'package:cloud_firestore/cloud_firestore.dart';

class IngredientModel {
  final String id;
  final String name;
  final double quantity;
  final String unit; // g, ml, quả, thìa, bó...

  IngredientModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory IngredientModel.fromMap(Map<String, dynamic> map) {
    return IngredientModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
    );
  }
}

class NutritionModel {
  final double calories; // kcal
  final double protein; // g
  final double carbs; // g
  final double fat; // g
  final double sodium; // mg
  final double fiber; // g

  NutritionModel({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sodium = 0,
    this.fiber = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'sodium': sodium,
      'fiber': fiber,
    };
  }

  factory NutritionModel.fromMap(Map<String, dynamic> map) {
    return NutritionModel(
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      sodium: (map['sodium'] ?? 0).toDouble(),
      fiber: (map['fiber'] ?? 0).toDouble(),
    );
  }
}

class MealModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String category; // pork, beef, chicken, soup, etc.
  final String mealType; // main, soup, vegetable, side, dessert, drink
  final List<IngredientModel> ingredients;
  final List<String> instructions;
  final int prepTime; // minutes
  final int cookTime; // minutes
  final int servings;
  final double estimatedCost; // VNĐ
  final NutritionModel nutrition;
  final List<String> tags;
  final String difficulty; // easy, medium, hard
  final int spiceLevel; // 0: non-spicy, 1: mildly spicy, etc.
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealModel({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    this.category = 'other',
    this.mealType = 'main',
    this.ingredients = const [],
    this.instructions = const [],
    this.prepTime = 0,
    this.cookTime = 0,
    this.servings = 1,
    this.estimatedCost = 0,
    required this.nutrition,
    this.tags = const [],
    this.difficulty = 'easy',
    this.spiceLevel = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  MealModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? category,
    String? mealType,
    List<IngredientModel>? ingredients,
    List<String>? instructions,
    int? prepTime,
    int? cookTime,
    int? servings,
    double? estimatedCost,
    NutritionModel? nutrition,
    List<String>? tags,
    String? difficulty,
    int? spiceLevel,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      mealType: mealType ?? this.mealType,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      nutrition: nutrition ?? this.nutrition,
      tags: tags ?? this.tags,
      difficulty: difficulty ?? this.difficulty,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'mealType': mealType,
      'ingredients': ingredients.map((x) => x.toMap()).toList(),
      'instructions': instructions,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'estimatedCost': estimatedCost,
      'nutrition': nutrition.toMap(),
      'tags': tags,
      'difficulty': difficulty,
      'spiceLevel': spiceLevel,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MealModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MealModel(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      category: map['category'] ?? 'other',
      mealType: map['mealType'] ?? 'main',
      ingredients: List<IngredientModel>.from((map['ingredients'] ?? []).map((x) => IngredientModel.fromMap(x))),
      instructions: List<String>.from(map['instructions'] ?? []),
      prepTime: map['prepTime'] ?? 0,
      cookTime: map['cookTime'] ?? 0,
      servings: map['servings'] ?? 1,
      estimatedCost: (map['estimatedCost'] ?? 0).toDouble(),
      nutrition: NutritionModel.fromMap(map['nutrition'] ?? {}),
      tags: List<String>.from(map['tags'] ?? []),
      difficulty: map['difficulty'] ?? 'easy',
      spiceLevel: map['spiceLevel'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
