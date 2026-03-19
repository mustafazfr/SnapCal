import 'package:health/health.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

/// Singleton service for reading step data from Apple Health / Google Health Connect.
class HealthService {
  static final HealthService instance = HealthService._();
  HealthService._();

  final Health _health = Health();
  bool _authorized = false;

  /// Whether health integration is enabled in user settings.
  bool get isEnabled => StorageService.instance.healthEnabled;

  /// Request permission to read step data. Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      // Configure Health Connect on Android
      Health().configure();

      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      _authorized = granted;
      return granted;
    } catch (e) {
      _authorized = false;
      return false;
    }
  }

  /// Check if we already have health permissions.
  Future<bool> hasPermissions() async {
    try {
      final types = [HealthDataType.STEPS];
      final granted = await _health.hasPermissions(types);
      _authorized = granted ?? false;
      return _authorized;
    } catch (_) {
      return false;
    }
  }

  /// Get total step count for a specific date (midnight to midnight).
  Future<int> getStepsForDate(DateTime date) async {
    if (!_authorized && !await hasPermissions()) return 0;

    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get weekly step data as a map of DateTime -> step count.
  Future<Map<DateTime, int>> getWeeklySteps(DateTime weekStart) async {
    final result = <DateTime, int>{};
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      result[date] = await getStepsForDate(date);
    }
    return result;
  }

  /// Estimate calories burned from a given step count.
  static int estimateCaloriesBurned(int steps) {
    return (steps * AppConstants.caloriesPerStep).round();
  }
}
