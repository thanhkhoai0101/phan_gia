import 'package:equatable/equatable.dart';
import '../models/meal_model.dart';
import '../models/meal_plan_model.dart';
import '../models/shopping_list_model.dart';

abstract class HouseholdEvent extends Equatable {
  const HouseholdEvent();

  @override
  List<Object> get props => [];
}

class LoadMeals extends HouseholdEvent {}

class CreateMealEvent extends HouseholdEvent {
  final MealModel meal;

  const CreateMealEvent(this.meal);

  @override
  List<Object> get props => [meal];
}

class DashboardDataUpdated extends HouseholdEvent {
  final List<MealModel> meals;
  final List<MealPlanModel> mealPlans;
  final List<ShoppingListModel> shoppingLists;

  const DashboardDataUpdated(this.meals, this.mealPlans, this.shoppingLists);

  @override
  List<Object> get props => [meals, mealPlans, shoppingLists];
}

