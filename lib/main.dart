import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/health_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/log_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'utils/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await StorageService.instance.init();
  await HealthService.instance.init();
  runApp(const CalorieLensApp());
}

class CalorieLensApp extends StatefulWidget {
  const CalorieLensApp({super.key});

  @override
  State<CalorieLensApp> createState() => _CalorieLensAppState();
}

class _CalorieLensAppState extends State<CalorieLensApp> {
  late ThemeMode _themeMode;
  late AppLanguage _language;

  @override
  void initState() {
    super.initState();
    _themeMode = StorageService.instance.themeMode;
    _language = _resolveLanguage();
  }

  AppLanguage _resolveLanguage() {
    final stored = StorageService.instance.language;
    if (stored == 'tr') return AppLanguage.tr;
    if (stored == 'en') return AppLanguage.en;
    // system — detect from platform
    try {
      final locale = Platform.localeName;
      if (locale.startsWith('tr')) return AppLanguage.tr;
    } catch (_) {}
    return AppLanguage.en;
  }

  void _onThemeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void _onLanguageChanged(AppLanguage lang) {
    setState(() => _language = lang);
  }

  @override
  Widget build(BuildContext context) {
    return AppLocalizations(
      language: _language,
      child: MaterialApp(
        title: 'CalorieLens',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: StorageService.instance.onboardingDone
            ? _Root(
                onThemeChanged: _onThemeChanged,
                onLanguageChanged: _onLanguageChanged,
              )
            : OnboardingScreen(
                onComplete: () {
                  StorageService.instance.setOnboardingDone(true);
                  setState(() {});
                },
              ),
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = const Color(0xFFE8622A);

    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: isDark ? const Color(0xFFFF9668) : const Color(0xFFE8622A),
      secondary: isDark ? const Color(0xFF7DC46A) : const Color(0xFF5C9E4A),
      tertiary: isDark ? const Color(0xFFFFC84A) : const Color(0xFFF4A020),
      surface: isDark ? const Color(0xFF1C1B1B) : const Color(0xFFFFF8F5),
      surfaceContainerHighest:
          isDark ? const Color(0xFF2C2B2B) : const Color(0xFFF5EBE4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surfaceContainerHighest,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withValues(alpha: 0.45),
        backgroundColor: cs.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Root scaffold with bottom navigation ────────────────────────────────────

class _Root extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  final void Function(AppLanguage) onLanguageChanged;
  const _Root({required this.onThemeChanged, required this.onLanguageChanged});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  int _index = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const LogScreen(),
      const StatsScreen(),
      SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        onLanguageChanged: widget.onLanguageChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: cs.primary.withValues(alpha: 0.12),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.camera_alt_outlined),
            selectedIcon: const Icon(Icons.camera_alt_rounded),
            label: loc.get('nav_analyze'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt_rounded),
            label: loc.get('nav_log'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: loc.get('nav_stats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: loc.get('nav_settings'),
          ),
        ],
      ),
    );
  }
}
