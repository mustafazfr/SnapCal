import 'package:flutter/material.dart';

enum AppLanguage { en, tr }

extension AppLanguageExt on AppLanguage {
  String get label => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.tr => 'Türkçe',
      };

  String get flag => switch (this) {
        AppLanguage.en => '🇬🇧',
        AppLanguage.tr => '🇹🇷',
      };
}

class AppLocalizations extends InheritedWidget {
  final AppLanguage language;

  const AppLocalizations({
    super.key,
    required this.language,
    required super.child,
  });

  static AppLocalizations of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocalizations>()!;
  }

  String get(String key) => _strings[language]?[key] ?? _strings[AppLanguage.en]![key] ?? key;

  @override
  bool updateShouldNotify(AppLocalizations oldWidget) =>
      language != oldWidget.language;

  static const Map<AppLanguage, Map<String, String>> _strings = {
    AppLanguage.en: {
      // Navigation
      'nav_analyze': 'Analyze',
      'nav_log': 'Log',
      'nav_stats': 'Stats',
      'nav_settings': 'Settings',

      // Home Screen
      'app_title': 'CalorieLens',
      'tap_to_add_photo': 'Tap to add a food photo',
      'camera_or_gallery': 'Camera or gallery',
      'analyze_food': 'Analyze Food',
      'how_it_works': 'How it works',
      'how_it_works_text':
          '1. Tap the upload area to take or choose a food photo.\n\n'
              '2. Press Analyze — CalorieLens sends the image to Claude AI.\n\n'
              '3. The AI returns estimated calories, portion size, and macros.\n\n'
              '4. Save the meal to your daily log.',
      'got_it': 'Got it',
      'take_photo': 'Take photo',
      'ai_analysis': 'AI analysis',
      'log_meal': 'Log meal',
      'powered_by': 'Powered by Claude AI',
      'take_a_photo': 'Take a photo',
      'choose_from_gallery': 'Choose from gallery',
      'change': 'Change',
      'camera_error': 'Could not access camera/gallery. Check app permissions.',
      'something_went_wrong': 'Something went wrong. Please try again.',
      'saved_to_log': 'saved to log!',
      'retry': 'Retry',

      // Error messages
      'error_no_api_key': '🔑 No API key — add your Claude key in Settings.',
      'error_invalid_api_key': '🔑 Invalid API key — please check Settings.',
      'error_no_internet': '📶 No internet connection.',
      'error_rate_limited': '⏳ Rate limit reached — wait a moment and retry.',
      'error_unrecognized_food': '🍽️ Could not identify food. Try a clearer photo.',
      'error_insufficient_credits': '💳 Insufficient API credits. Please add credits at console.anthropic.com.',

      // Result Card
      'calories': 'calories',
      'save_to_log': 'Save to Log',
      'protein': 'Protein',
      'carbs': 'Carbs',
      'fat': 'Fat',
      'edit_values': 'Edit Values',
      'not_this_food': 'Wrong food?',
      'correct_food_title': 'What is this food?',
      'correct_food_hint': 'e.g. grilled chicken, pasta...',
      'reanalyze': 'Re-analyze',
      'confidence_high': 'High',
      'confidence_medium': 'Medium',
      'confidence_low': 'Low',
      'food_name': 'Food name',
      'portion_size': 'Portion size',
      'save_changes': 'Save Changes',
      'cancel': 'Cancel',

      // Log Screen
      'meal_log': 'Meal Log',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'tap_to_return': 'Tap to return to today',
      'meal_deleted': 'Meal deleted',
      'undo': 'Undo',
      'delete_meal': 'Delete meal?',
      'delete_meal_confirm': 'This meal will be removed from your log.',
      'delete': 'Delete',
      'no_meals_today': 'No meals logged today',
      'no_meals_this_day': 'No meals on this day',
      'analyze_to_start': 'Analyze a food photo to get started',
      'navigate_other_day': 'Navigate to another day',

      // Stats Screen
      'statistics': 'Statistics',
      'this_week': 'This week',
      'weekly_summary': 'Weekly Summary',
      'daily_breakdown': 'Daily Breakdown',
      'daily_avg': 'Daily avg',
      'highest_day': 'Highest day',
      'days_logged': 'Days logged',
      'under_goal': 'Under goal',
      'of_days': '% of days',
      'no_meals_this_week': 'No meals logged this week',
      'log_meals_chart': 'Log some meals to see your chart',
      'no_meals_logged': 'No meals logged',
      'under_goal_legend': 'Under goal',
      'near_limit_legend': 'Near limit (>90%)',
      'over_goal_legend': 'Over goal',
      'goal': 'Goal',

      // Settings Screen
      'settings': 'Settings',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'daily_calorie_goal': 'Daily Calorie Goal',
      'target_calories': 'Target calories',
      'goal_description': 'Shown as the goal in your Log progress bar',
      'set_goal': 'Set Goal',
      'enter_valid_calorie': 'Enter a valid calorie number',
      'goal_set_to': 'Daily goal set to',
      'kcal': 'kcal',
      'tdee_calculator': 'TDEE Calculator',
      'mifflin_formula': 'Mifflin-St Jeor formula',
      'tdee_description': 'Calculate your BMR and daily energy expenditure',
      'male': 'Male',
      'female': 'Female',
      'age': 'Age',
      'yrs': 'yrs',
      'weight': 'Weight',
      'kg': 'kg',
      'height': 'Height',
      'cm': 'cm',
      'activity_level': 'Activity level',
      'calculate': 'Calculate',
      'fill_all_fields': 'Fill in all fields to calculate',
      'realistic_age': 'Enter a realistic age (10–120)',
      'bmr': 'BMR',
      'kcal_day_rest': 'kcal/day at rest',
      'tdee': 'TDEE',
      'total_daily': 'total daily expenditure',
      'suggested_goals': 'Suggested goals',
      'lose_weight': 'Lose weight',
      'maintain': 'Maintain',
      'gain_weight': 'Gain weight',
      'kcal_day': 'kcal / day',
      'data': 'Data',
      'clear_all_data': 'Clear all data',
      'clear_all_subtitle': 'Permanently delete all meals and settings',
      'clear_all_confirm': 'All logged meals and settings will be permanently deleted.',
      'clear_everything': 'Clear everything',
      'all_data_cleared': 'All data cleared',
      'language': 'Language',

      // API Key
      'api_key': 'API Key',
      'claude_api_key': 'Claude API Key',
      'api_key_description': 'Required for food photo analysis',
      'api_key_hint': 'sk-ant-...',
      'save_key': 'Save Key',
      'test_key': 'Test Key',
      'api_key_saved': 'API key saved',
      'api_key_valid': 'API key is valid!',
      'api_key_invalid': 'API key is invalid. Please check and try again.',
      'testing_key': 'Testing API key...',

      // Onboarding
      'welcome_title': 'Welcome to CalorieLens',
      'welcome_subtitle': 'Track your calories with AI-powered food analysis',
      'onboarding_step1_title': 'Take a Photo',
      'onboarding_step1_desc': 'Snap a picture of your meal using your camera or choose from gallery',
      'onboarding_step2_title': 'AI Analysis',
      'onboarding_step2_desc': 'Claude AI analyzes your food and estimates calories, protein, carbs and fat',
      'onboarding_step3_title': 'Track Progress',
      'onboarding_step3_desc': 'Save meals to your log and monitor your daily and weekly nutrition goals',
      'enter_api_key': 'Enter your Claude API key to get started',
      'get_started': 'Get Started',
      'skip': 'Skip',
      'next': 'Next',
      'ok': 'OK',

      // Activity levels
      'sedentary': 'Sedentary (office job)',
      'lightly_active': 'Lightly active (1-2 days/week)',
      'moderately_active': 'Moderately active (3-5 days/week)',
      'very_active': 'Very active (6-7 days/week)',
      'extra_active': 'Extra active (athlete)',

      // Health Integration
      'health_integration': 'Health Integration',
      'step_tracking': 'Step Tracking',
      'step_tracking_desc': 'Read steps from Apple Health or Health Connect',
      'health_permission_denied': 'Health permission denied. Enable in device Settings.',
      'health_not_available': 'Health data not available on this device.',
      'daily_steps': 'Daily steps',
      'calories_burned': 'Calories burned',
      'steps': 'steps',
      'burned': 'Burned',
      'net_calories': 'Net calories',
      'activity': 'Activity',
      'avg_steps': 'Avg steps',
      'est_burned': 'Est. burned',
      'steps_label': 'Steps',
      'net': 'Net',
    },
    AppLanguage.tr: {
      // Navigation
      'nav_analyze': 'Analiz',
      'nav_log': 'Günlük',
      'nav_stats': 'İstatistik',
      'nav_settings': 'Ayarlar',

      // Home Screen
      'app_title': 'CalorieLens',
      'tap_to_add_photo': 'Yemek fotoğrafı eklemek için dokunun',
      'camera_or_gallery': 'Kamera veya galeri',
      'analyze_food': 'Yemeği Analiz Et',
      'how_it_works': 'Nasıl çalışır',
      'how_it_works_text':
          '1. Yükleme alanına dokunarak yemek fotoğrafı çekin veya seçin.\n\n'
              '2. Analiz Et\'e basın — CalorieLens görseli Claude AI\'a gönderir.\n\n'
              '3. AI tahmini kalori, porsiyon ve makro değerlerini döndürür.\n\n'
              '4. Yemeği günlük kaydınıza ekleyin.',
      'got_it': 'Anladım',
      'take_photo': 'Foto çek',
      'ai_analysis': 'AI analizi',
      'log_meal': 'Kaydet',
      'powered_by': 'Claude AI ile çalışır',
      'take_a_photo': 'Fotoğraf çek',
      'choose_from_gallery': 'Galeriden seç',
      'change': 'Değiştir',
      'camera_error': 'Kamera/galeriye erişilemedi. Uygulama izinlerini kontrol edin.',
      'something_went_wrong': 'Bir şeyler ters gitti. Lütfen tekrar deneyin.',
      'saved_to_log': 'günlüğe kaydedildi!',
      'retry': 'Tekrar Dene',

      // Error messages
      'error_no_api_key': '🔑 API key yok — Ayarlar\'dan Claude key\'inizi ekleyin.',
      'error_invalid_api_key': '🔑 Geçersiz API key — lütfen Ayarlar\'ı kontrol edin.',
      'error_no_internet': '📶 İnternet bağlantısı yok.',
      'error_rate_limited': '⏳ API limiti doldu — biraz bekleyip tekrar deneyin.',
      'error_unrecognized_food': '🍽️ Yemek tanınamadı. Daha net bir fotoğraf deneyin.',
      'error_insufficient_credits': '💳 API kredisi yetersiz. console.anthropic.com adresinden kredi yükleyin.',

      // Result Card
      'calories': 'kalori',
      'save_to_log': 'Günlüğe Kaydet',
      'protein': 'Protein',
      'carbs': 'Karbonhidrat',
      'fat': 'Yağ',
      'edit_values': 'Değerleri Düzenle',
      'not_this_food': 'Yanlış yemek mi?',
      'correct_food_title': 'Bu yemek ne?',
      'correct_food_hint': 'ör. ızgara tavuk, makarna...',
      'reanalyze': 'Tekrar Analiz Et',
      'confidence_high': 'Yüksek',
      'confidence_medium': 'Orta',
      'confidence_low': 'Düşük',
      'food_name': 'Yemek adı',
      'portion_size': 'Porsiyon boyutu',
      'save_changes': 'Değişiklikleri Kaydet',
      'cancel': 'İptal',

      // Log Screen
      'meal_log': 'Yemek Günlüğü',
      'today': 'Bugün',
      'yesterday': 'Dün',
      'tap_to_return': 'Bugüne dönmek için dokunun',
      'meal_deleted': 'Yemek silindi',
      'undo': 'Geri Al',
      'delete_meal': 'Yemek silinsin mi?',
      'delete_meal_confirm': 'Bu yemek günlüğünüzden kaldırılacak.',
      'delete': 'Sil',
      'no_meals_today': 'Bugün yemek kaydedilmedi',
      'no_meals_this_day': 'Bu gün yemek kaydedilmedi',
      'analyze_to_start': 'Başlamak için bir yemek fotoğrafı analiz edin',
      'navigate_other_day': 'Başka bir güne geç',

      // Stats Screen
      'statistics': 'İstatistikler',
      'this_week': 'Bu hafta',
      'weekly_summary': 'Haftalık Özet',
      'daily_breakdown': 'Günlük Detay',
      'daily_avg': 'Günlük ort.',
      'highest_day': 'En yüksek gün',
      'days_logged': 'Kaydedilen gün',
      'under_goal': 'Hedefin altında',
      'of_days': '% günlerde',
      'no_meals_this_week': 'Bu hafta yemek kaydedilmedi',
      'log_meals_chart': 'Grafik için yemek kaydedin',
      'no_meals_logged': 'Yemek kaydedilmedi',
      'under_goal_legend': 'Hedefin altında',
      'near_limit_legend': 'Limite yakın (>%90)',
      'over_goal_legend': 'Hedefin üzerinde',
      'goal': 'Hedef',

      // Settings Screen
      'settings': 'Ayarlar',
      'appearance': 'Görünüm',
      'theme': 'Tema',
      'light': 'Açık',
      'dark': 'Koyu',
      'system': 'Sistem',
      'daily_calorie_goal': 'Günlük Kalori Hedefi',
      'target_calories': 'Hedef kalori',
      'goal_description': 'Günlük ilerleme çubuğunda hedef olarak gösterilir',
      'set_goal': 'Hedefi Kaydet',
      'enter_valid_calorie': 'Geçerli bir kalori değeri girin',
      'goal_set_to': 'Günlük hedef',
      'kcal': 'kcal',
      'tdee_calculator': 'TDEE Hesaplayıcı',
      'mifflin_formula': 'Mifflin-St Jeor formülü',
      'tdee_description': 'BMR ve günlük enerji harcamanızı hesaplayın',
      'male': 'Erkek',
      'female': 'Kadın',
      'age': 'Yaş',
      'yrs': 'yaş',
      'weight': 'Kilo',
      'kg': 'kg',
      'height': 'Boy',
      'cm': 'cm',
      'activity_level': 'Aktivite seviyesi',
      'calculate': 'Hesapla',
      'fill_all_fields': 'Hesaplamak için tüm alanları doldurun',
      'realistic_age': 'Gerçekçi bir yaş girin (10–120)',
      'bmr': 'BMR',
      'kcal_day_rest': 'kcal/gün dinlenme',
      'tdee': 'TDEE',
      'total_daily': 'toplam günlük harcama',
      'suggested_goals': 'Önerilen hedefler',
      'lose_weight': 'Kilo ver',
      'maintain': 'Koru',
      'gain_weight': 'Kilo al',
      'kcal_day': 'kcal / gün',
      'data': 'Veriler',
      'clear_all_data': 'Tüm verileri sil',
      'clear_all_subtitle': 'Tüm yemekler ve ayarlar kalıcı olarak silinir',
      'clear_all_confirm': 'Tüm kaydedilen yemekler ve ayarlar kalıcı olarak silinecek.',
      'clear_everything': 'Her şeyi sil',
      'all_data_cleared': 'Tüm veriler silindi',
      'language': 'Dil',

      // API Key
      'api_key': 'API Anahtarı',
      'claude_api_key': 'Claude API Anahtarı',
      'api_key_description': 'Yemek fotoğrafı analizi için gereklidir',
      'api_key_hint': 'sk-ant-...',
      'save_key': 'Kaydet',
      'test_key': 'Test Et',
      'api_key_saved': 'API anahtarı kaydedildi',
      'api_key_valid': 'API anahtarı geçerli!',
      'api_key_invalid': 'API anahtarı geçersiz. Lütfen kontrol edin.',
      'testing_key': 'API anahtarı test ediliyor...',

      // Onboarding
      'welcome_title': 'CalorieLens\'e Hoş Geldiniz',
      'welcome_subtitle': 'AI destekli yemek analizi ile kalorilerinizi takip edin',
      'onboarding_step1_title': 'Fotoğraf Çekin',
      'onboarding_step1_desc': 'Kameranızla yemeğinizin fotoğrafını çekin veya galeriden seçin',
      'onboarding_step2_title': 'AI Analizi',
      'onboarding_step2_desc': 'Claude AI yemeğinizi analiz ederek kalori, protein, karbonhidrat ve yağ değerlerini tahmin eder',
      'onboarding_step3_title': 'İlerlemenizi Takip Edin',
      'onboarding_step3_desc': 'Yemekleri günlüğünüze kaydedin ve günlük/haftalık beslenme hedeflerinizi izleyin',
      'enter_api_key': 'Başlamak için Claude API anahtarınızı girin',
      'get_started': 'Başla',
      'skip': 'Atla',
      'next': 'İleri',
      'ok': 'Tamam',

      // Activity levels
      'sedentary': 'Hareketsiz (ofis işi)',
      'lightly_active': 'Az hareketli (haftada 1-2 gün)',
      'moderately_active': 'Orta hareketli (haftada 3-5 gün)',
      'very_active': 'Çok hareketli (haftada 6-7 gün)',
      'extra_active': 'Ekstra hareketli (sporcu)',

      // Health Integration
      'health_integration': 'Sağlık Entegrasyonu',
      'step_tracking': 'Adım Takibi',
      'step_tracking_desc': 'Apple Health veya Health Connect\'ten adım oku',
      'health_permission_denied': 'Sağlık izni reddedildi. Cihaz Ayarlarından etkinleştirin.',
      'health_not_available': 'Bu cihazda sağlık verisi mevcut değil.',
      'daily_steps': 'Günlük adım',
      'calories_burned': 'Yakılan kalori',
      'steps': 'adım',
      'burned': 'Yakılan',
      'net_calories': 'Net kalori',
      'activity': 'Aktivite',
      'avg_steps': 'Ort. adım',
      'est_burned': 'Tahmini yakılan',
      'steps_label': 'Adım',
      'net': 'Net',
    },
  };
}
