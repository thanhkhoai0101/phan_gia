import 'package:equatable/equatable.dart';
import '../models/meal_model.dart';
import '../models/meal_plan_model.dart';
import '../models/shopping_list_model.dart';

abstract class HouseholdState extends Equatable {
  const HouseholdState();
  
  @override
  List<Object> get props => [];
}

class HouseholdInitial extends HouseholdState {}

class HouseholdLoading extends HouseholdState {}

class HouseholdLoaded extends HouseholdState {
  final List<MealModel> meals;
  final List<MealPlanModel> mealPlans;
  final List<ShoppingListModel> shoppingLists;
  
  const HouseholdLoaded({
    required this.meals,
    this.mealPlans = const [],
    this.shoppingLists = const [],
  });
  
  @override
  List<Object> get props => [meals, mealPlans, shoppingLists];
}

class HouseholdError extends HouseholdState {
  final String message;
  
  const HouseholdError(this.message);
  
  @override
  List<Object> get props => [message];
}
