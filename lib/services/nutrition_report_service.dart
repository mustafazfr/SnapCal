import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';

class NutritionReport {
  final String text;
  final DateTime start;
  final DateTime end;
  final int avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final int loggedDays;
  final int totalDays;

  const NutritionReport({
    required this.text,
    required this.start,
    required this.end,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    required this.loggedDays,
    required this.totalDays,
  });
}

class NutritionReportService {
  static final instance = NutritionReportService._();
  NutritionReportService._();

  final _claude = ClaudeService();

  Future<NutritionReport> generate({
    required DateTime start,
    required DateTime end,
    required String langCode,
  }) async {
    final meals = await StorageService.instance.getMealsInRange(start, end);
    final goal = StorageService.instance.calorieGoal;
    final fmt = DateFormat('d MMM yyyy');

    // Group meals by day
    final byDay = <String, List<Meal>>{};
    for (final m in meals) {
      final key = DateFormat('yyyy-MM-dd').format(m.timestamp);
      byDay.putIfAbsent(key, () => []).add(m);
    }

    final totalDays = end.difference(start).inDays + 1;
    final loggedDays = byDay.length;

    int totalCal = 0;
    double totalProtein = 0, totalCarbs = 0, totalFat = 0;
    int underGoal = 0, overGoal = 0;
    final foodCount = <String, int>{};

    for (final dayMeals in byDay.values) {
      final dayCal = dayMeals.fold(0, (s, m) => s + m.calories);
      totalCal += dayCal;
      totalProtein += dayMeals.fold(0.0, (s, m) => s + m.protein);
      totalCarbs += dayMeals.fold(0.0, (s, m) => s + m.carbs);
      totalFat += dayMeals.fold(0.0, (s, m) => s + m.fat);
      if (dayCal > 0 && dayCal <= goal) underGoal++;
      if (dayCal > goal) overGoal++;
      for (final m in dayMeals) {
        foodCount[m.foodName] = (foodCount[m.foodName] ?? 0) + 1;
      }
    }

    final n = loggedDays > 0 ? loggedDays : 1;
    final avgCal = totalCal ~/ n;
    final avgProt = totalProtein / n;
    final avgCarb = totalCarbs / n;
    final avgFat = totalFat / n;

    // Top 5 foods
    final topFoods = (foodCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => e.key)
        .join(', ');

    final stats = {
      'calorie_goal': goal,
      'start_date': fmt.format(start),
      'end_date': fmt.format(end),
      'total_days': totalDays,
      'logged_days': loggedDays,
      'avg_calories': avgCal,
      'avg_protein': avgProt.toStringAsFixed(1),
      'avg_carbs': avgCarb.toStringAsFixed(1),
      'avg_fat': avgFat.toStringAsFixed(1),
      'top_foods': topFoods.isEmpty ? '-' : topFoods,
      'under_goal_days': underGoal,
      'over_goal_days': overGoal,
    };

    final reportText = await _claude.generateNutritionReport(
      stats: stats,
      langCode: langCode,
    );

    return NutritionReport(
      text: reportText,
      start: start,
      end: end,
      avgCalories: avgCal,
      avgProtein: avgProt,
      avgCarbs: avgCarb,
      avgFat: avgFat,
      loggedDays: loggedDays,
      totalDays: totalDays,
    );
  }
}
