enum Gender { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

extension ActivityLevelX on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary (little/no exercise)';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active (1–3 days/week)';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active (3–5 days/week)';
      case ActivityLevel.veryActive:
        return 'Very Active (6–7 days/week)';
      case ActivityLevel.extraActive:
        return 'Extra Active (athlete/physical job)';
    }
  }

  double get factor {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.725;
      case ActivityLevel.extraActive:
        return 1.9;
    }
  }
}

class TDEEResult {
  final int bmr;
  final int tdee;
  final int lossGoal;
  final int maintainGoal;
  final int gainGoal;

  const TDEEResult({
    required this.bmr,
    required this.tdee,
    required this.lossGoal,
    required this.maintainGoal,
    required this.gainGoal,
  });
}

class TDEECalculator {
  /// Mifflin-St Jeor BMR
  static double _bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return gender == Gender.male ? base + 5 : base - 161;
  }

  static TDEEResult calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
    required ActivityLevel activityLevel,
  }) {
    final bmr = _bmr(
        weightKg: weightKg, heightCm: heightCm, age: age, gender: gender);
    final tdee = bmr * activityLevel.factor;
    return TDEEResult(
      bmr: bmr.round(),
      tdee: tdee.round(),
      lossGoal: (tdee - 500).round().clamp(1200, 999999),
      maintainGoal: tdee.round(),
      gainGoal: (tdee + 500).round(),
    );
  }
}
