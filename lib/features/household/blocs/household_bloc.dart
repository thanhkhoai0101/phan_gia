import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/meal_model.dart';
import '../services/household_service.dart';
import 'household_event.dart';
import 'household_state.dart';

class HouseholdBloc extends Bloc<HouseholdEvent, HouseholdState> {
  final HouseholdService _householdService;
  StreamSubscription? _mealsSubscription;

  HouseholdBloc(this._householdService) : super(HouseholdInitial()) {
    on<LoadMeals>(_onLoadMeals);
    on<CreateMealEvent>(_onCreateMeal);
    on<_MealsUpdated>(_onMealsUpdated);
  }

  void _onMealsUpdated(_MealsUpdated event, Emitter<HouseholdState> emit) {
    emit(HouseholdLoaded(meals: event.meals));
  }

  void _onLoadMeals(LoadMeals event, Emitter<HouseholdState> emit) {
    emit(HouseholdLoading());
    _mealsSubscription?.cancel();
    _mealsSubscription = _householdService.getMeals().listen((meals) {
      add(_MealsUpdated(meals));
    });
  }

  void _onCreateMeal(CreateMealEvent event, Emitter<HouseholdState> emit) async {
    try {
      await _householdService.createMeal(event.meal);
    } catch (e) {
      emit(HouseholdError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _mealsSubscription?.cancel();
    return super.close();
  }
}

class _MealsUpdated extends HouseholdEvent {
  final List<MealModel> meals;
  const _MealsUpdated(this.meals);

  @override
  List<Object> get props => [meals];
}
