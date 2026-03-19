import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  AppLanguage _selectedLang = AppLanguage.en;

  static const _totalPages = 4; // lang select + 3 info pages

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _selectLanguage(AppLanguage lang) {
    setState(() => _selectedLang = lang);
  }

  void _next() {
    if (_currentPage == 0) {
      // Save language choice
      StorageService.instance
          .setLanguage(_selectedLang == AppLanguage.tr ? 'tr' : 'en');
    }
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finish() {
    if (_currentPage == 0) {
      StorageService.instance
          .setLanguage(_selectedLang == AppLanguage.tr ? 'tr' : 'en');
    }
    widget.onComplete();
  }

  // Get localized string based on selected language
  String _t(String enText, String trText) {
    return _selectedLang == AppLanguage.tr ? trText : enText;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    _t('Skip', 'Atla'),
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Page 0: Language selection
                  _LanguagePage(
                    selectedLang: _selectedLang,
                    onSelect: _selectLanguage,
                  ),
                  // Page 1: Welcome
                  _OnboardingPage(
                    icon: Icons.camera_alt_rounded,
                    iconColor: cs.secondary,
                    title: _t('Take a Photo', 'Fotoğraf Çekin'),
                    subtitle: _t(
                      'Snap a picture of your meal using your camera or choose from gallery',
                      'Kameranızla yemeğinizin fotoğrafını çekin veya galeriden seçin',
                    ),
                  ),
                  // Page 2: AI Analysis
                  _OnboardingPage(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: cs.tertiary,
                    title: _t('AI Analysis', 'AI Analizi'),
                    subtitle: _t(
                      'Claude AI analyzes your food and estimates calories, protein, carbs and fat',
                      'Claude AI yemeğinizi analiz ederek kalori, protein, karbonhidrat ve yağ değerlerini tahmin eder',
                    ),
                  ),
                  // Page 3: Track
                  _OnboardingPage(
                    icon: Icons.bar_chart_rounded,
                    iconColor: cs.primary,
                    title: _t('Track Progress', 'İlerlemenizi Takip Edin'),
                    subtitle: _t(
                      'Save meals to your log and monitor your daily and weekly nutrition goals',
                      'Yemekleri günlüğünüze kaydedin ve günlük/haftalık beslenme hedeflerinizi izleyin',
                    ),
                  ),
                ],
              ),
            ),

            // Dots + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? cs.primary
                              : cs.primary.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _currentPage == _totalPages - 1
                          ? _finish
                          : _next,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentPage == _totalPages - 1
                            ? _t('Get Started', 'Başla')
                            : _t('Next', 'İleri'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language selection page ───────────────────────────────────────────────────

class _LanguagePage extends StatelessWidget {
  final AppLanguage selectedLang;
  final void Function(AppLanguage) onSelect;

  const _LanguagePage({
    required this.selectedLang,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.language_rounded,
                size: 56, color: cs.primary),
          ),
          const SizedBox(height: 36),
          Text(
            'Select Language\nDil Seçin',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _LangOption(
                  flag: '🇬🇧',
                  label: 'English',
                  selected: selectedLang == AppLanguage.en,
                  onTap: () => onSelect(AppLanguage.en),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LangOption(
                  flag: '🇹🇷',
                  label: 'Türkçe',
                  selected: selectedLang == AppLanguage.tr,
                  onTap: () => onSelect(AppLanguage.tr),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info page ─────────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: iconColor),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.60),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
