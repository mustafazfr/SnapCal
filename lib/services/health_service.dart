import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

/// Singleton service for reading step data from Apple Health / Google Health Connect.
class HealthService {
  static final HealthService instance = HealthService._();
  HealthService._();

  final Health _health = Health();
  bool _configured = false;
  bool _authorized = false;

  /// Whether health integration is enabled in user settings.
  bool get isEnabled => StorageService.instance.healthEnabled;

  /// Restore authorization state on app launch.
  /// Call this once after StorageService is initialized.
  Future<void> init() async {
    if (isEnabled) {
      await requestPermissions();
    }
  }

  /// Configure the health plugin (idempotent).
  Future<void> _ensureConfigured() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
  }

  /// Request permission to read step data. Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();

      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      // Always call requestAuthorization — on iOS hasPermissions() is
      // unreliable (returns null) so we can't trust it.
      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      _authorized = granted;
      debugPrint('[SnapCal] Health requestAuthorization → $granted');
      return granted;
    } catch (e) {
      debugPrint('[SnapCal] Health requestPermissions error: $e');
      _authorized = false;
      return false;
    }
  }

  /// Get total step count for a specific date (midnight to midnight).
  Future<int> getStepsForDate(DateTime date) async {
    if (!isEnabled) return 0;

    // Ensure we have authorization (re-request if needed)
    if (!_authorized) {
      await requestPermissions();
      if (!_authorized) return 0;
    }

    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (e) {
      // Retry once after re-configuring (HealthKit sometimes needs a warm-up)
      debugPrint('[SnapCal] Steps query failed, retrying: $e');
      try {
        _configured = false;
        await _ensureConfigured();
        final steps = await _health.getTotalStepsInInterval(start, end);
        return steps ?? 0;
      } catch (_) {
        return 0;
      }
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
