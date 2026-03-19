/// App-wide constants and SharedPreferences keys.
class AppConstants {
  AppConstants._();

  static const String appName = 'CalorieLens';

  // SharedPreferences keys
  static const String prefApiKey = 'claude_api_key';
  static const String prefCalorieGoal = 'calorie_goal';
  static const String prefMealsPrefix = 'meals_';
  static const String prefThemeMode = 'theme_mode';
  static const String prefLanguage = 'language';
  static const String prefOnboardingDone = 'onboarding_done';

  static const int defaultCalorieGoal = 2000;
}
