import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal.dart';
import '../utils/constants.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  SharedPreferences? _prefs;

  StorageService._();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'StorageService.init() must be called first');
    return _prefs!;
  }

  // ── API Key ──────────────────────────────────────────────────────────────
  String get apiKey =>
      _p.getString(AppConstants.prefApiKey) ??
      const String.fromEnvironment('CLAUDE_API_KEY', defaultValue: '');

  Future<void> setApiKey(String key) =>
      _p.setString(AppConstants.prefApiKey, key);

  // ── Calorie Goal ─────────────────────────────────────────────────────────
  int get calorieGoal =>
      _p.getInt(AppConstants.prefCalorieGoal) ??
      AppConstants.defaultCalorieGoal;

  Future<void> setCalorieGoal(int goal) =>
      _p.setInt(AppConstants.prefCalorieGoal, goal);

  // ── Theme ─────────────────────────────────────────────────────────────────
  ThemeMode get themeMode {
    final v = _p.getString(AppConstants.prefThemeMode);
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _p.setString(AppConstants.prefThemeMode, v);
  }

  // ── Meals ────────────────────────────────────────────────────────────────
  Future<List<Meal>> getMealsForDate(DateTime date) async {
    final raw = _p.getString(_mealKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Meal.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> saveMeal(Meal meal) async {
    final meals = await getMealsForDate(meal.timestamp);
    meals.removeWhere((m) => m.id == meal.id);
    meals.add(meal);
    await _p.setString(
      _mealKey(meal.timestamp),
      jsonEncode(meals.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> deleteMeal(Meal meal) async {
    final meals = await getMealsForDate(meal.timestamp);
    meals.removeWhere((m) => m.id == meal.id);
    await _p.setString(
      _mealKey(meal.timestamp),
      jsonEncode(meals.map((m) => m.toJson()).toList()),
    );
  }

  /// Returns a map of DateTime → total calories for 7 days starting at [weekStart].
  Future<Map<DateTime, int>> getWeeklyCalories(DateTime weekStart) async {
    final result = <DateTime, int>{};
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final meals = await getMealsForDate(date);
      result[date] = meals.fold(0, (s, m) => s + m.calories);
    }
    return result;
  }

  // ── Language ─────────────────────────────────────────────────────────────
  String get language => _p.getString(AppConstants.prefLanguage) ?? 'system';

  Future<void> setLanguage(String lang) =>
      _p.setString(AppConstants.prefLanguage, lang);

  // ── Onboarding ──────────────────────────────────────────────────────────
  bool get onboardingDone =>
      _p.getBool(AppConstants.prefOnboardingDone) ?? false;

  Future<void> setOnboardingDone(bool done) =>
      _p.setBool(AppConstants.prefOnboardingDone, done);

  Future<void> clearAllData() => _p.clear();

  // ── Helpers ──────────────────────────────────────────────────────────────
  static String _mealKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${AppConstants.prefMealsPrefix}$y-$m-$d';
  }
}
