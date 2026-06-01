import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _key = 'isDarkMode';

  ThemeBloc({bool initialDark = true}) : super(ThemeState(initialDark ? ThemeMode.dark : ThemeMode.light)) {
    on<ThemeChanged>(_onThemeChanged);
  }

  Future<void> _onThemeChanged(ThemeChanged event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, event.isDarkMode);
    emit(ThemeState(event.isDarkMode ? ThemeMode.dark : ThemeMode.light));
  }

  static Future<bool> loadSavedDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true; // default dark
  }
}
