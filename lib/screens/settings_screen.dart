import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/health_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../utils/tdee_calculator.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  final void Function(AppLanguage) onLanguageChanged;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  // Calorie goal
  final _goalCtrl = TextEditingController();

  // Theme mode
  late ThemeMode _themeMode;

  // Language
  late AppLanguage _selectedLanguage;

  // Health
  late bool _healthEnabled;

  // TDEE form
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  Gender _gender = Gender.male;
  ActivityLevel _activity = ActivityLevel.moderatelyActive;
  TDEEResult? _tdeeResult;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = StorageService.instance.calorieGoal.toString();
    _themeMode = StorageService.instance.themeMode;
    _selectedLanguage = _resolveCurrentLanguage();
    _healthEnabled = StorageService.instance.healthEnabled;
  }

  AppLanguage _resolveCurrentLanguage() {
    final stored = StorageService.instance.language;
    if (stored == 'tr') return AppLanguage.tr;
    if (stored == 'en') return AppLanguage.en;
    return AppLanguage.en;
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  // ── Calorie goal ───────────────────────────────────────────────────────────

  Future<void> _saveGoal() async {
    final loc = AppLocalizations.of(context);
    final val = int.tryParse(_goalCtrl.text.trim());
    if (val == null || val <= 0) {
      _snack(loc.get('enter_valid_calorie'), error: true);
      return;
    }
    await StorageService.instance.setCalorieGoal(val);
    _snack('${loc.get('goal_set_to')} $val ${loc.get('kcal')}');
  }

  Future<void> _applyTDEEGoal(int kcal) async {
    final loc = AppLocalizations.of(context);
    await StorageService.instance.setCalorieGoal(kcal);
    setState(() => _goalCtrl.text = kcal.toString());
    widget.onThemeChanged(_themeMode);
    _snack('${loc.get('goal_set_to')} $kcal ${loc.get('kcal')}');
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  Future<void> _setTheme(ThemeMode mode) async {
    await StorageService.instance.setThemeMode(mode);
    setState(() => _themeMode = mode);
    widget.onThemeChanged(mode);
  }

  // ── Language ───────────────────────────────────────────────────────────────

  Future<void> _setLanguage(AppLanguage lang) async {
    await StorageService.instance.setLanguage(lang == AppLanguage.tr ? 'tr' : 'en');
    setState(() => _selectedLanguage = lang);
    widget.onLanguageChanged(lang);
  }

  // ── Health ───────────────────────────────────────────────────────────────

  Future<void> _toggleHealth(bool enabled) async {
    final loc = AppLocalizations.of(context);
    if (enabled) {
      final granted = await HealthService.instance.requestPermissions();
      if (!granted) {
        if (mounted) _snack(loc.get('health_permission_denied'), error: true);
        return;
      }
    }
    await StorageService.instance.setHealthEnabled(enabled);
    setState(() => _healthEnabled = enabled);
  }

  // ── TDEE calculator ────────────────────────────────────────────────────────

  void _calculate() {
    final loc = AppLocalizations.of(context);
    final age = int.tryParse(_ageCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());

    if (age == null || weight == null || height == null) {
      _snack(loc.get('fill_all_fields'), error: true);
      return;
    }
    if (age < 10 || age > 120) {
      _snack(loc.get('realistic_age'), error: true);
      return;
    }

    setState(() {
      _tdeeResult = TDEECalculator.calculate(
        age: age,
        weightKg: weight,
        heightCm: height,
        gender: _gender,
        activityLevel: _activity,
      );
    });
  }

  // ── Clear data ─────────────────────────────────────────────────────────────

  Future<void> _clearData() async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('clear_all_data')),
        content: Text(loc.get('clear_all_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.get('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.get('clear_everything')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService.instance.clearAllData();
    if (!mounted) return;
    setState(() {
      _goalCtrl.text = '2000';
      _tdeeResult = null;
    });
    _snack(loc.get('all_data_cleared'));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : null,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(loc.get('settings'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Language ─────────────────────────────────────────────────
          _Label(loc.get('language'), cs.primary),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(loc.get('language')),
                  const SizedBox(height: 12),
                  Row(
                    children: AppLanguage.values
                        .map((lang) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: lang != AppLanguage.values.last ? 6 : 0,
                                  left: lang != AppLanguage.values.first ? 6 : 0,
                                ),
                                child: _ThemeBtn(
                                  label: '${lang.flag} ${lang.label}',
                                  icon: null,
                                  selected: _selectedLanguage == lang,
                                  onTap: () => _setLanguage(lang),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────────
          _Label(loc.get('appearance'), cs.primary),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(loc.get('theme')),
                  const SizedBox(height: 12),
                  Row(
                    children: ThemeMode.values
                        .map((mode) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: mode != ThemeMode.dark ? 6 : 0,
                                  left: mode != ThemeMode.system ? 0 : 6,
                                ),
                                child: _ThemeBtn(
                                  label: switch (mode) {
                                    ThemeMode.light => loc.get('light'),
                                    ThemeMode.dark => loc.get('dark'),
                                    ThemeMode.system => loc.get('system'),
                                  },
                                  icon: switch (mode) {
                                    ThemeMode.light =>
                                      Icons.light_mode_rounded,
                                    ThemeMode.dark =>
                                      Icons.dark_mode_rounded,
                                    ThemeMode.system =>
                                      Icons.brightness_auto_rounded,
                                  },
                                  selected: _themeMode == mode,
                                  onTap: () => _setTheme(mode),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Health Integration ──────────────────────────────────────────
          _Label(loc.get('health_integration'), cs.primary),
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.directions_walk_rounded, color: cs.primary),
              title: Text(loc.get('step_tracking'),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(loc.get('step_tracking_desc')),
              value: _healthEnabled,
              onChanged: _toggleHealth,
            ),
          ),

          const SizedBox(height: 24),

          // ── Calorie Goal ───────────────────────────────────────────────
          _Label(loc.get('daily_calorie_goal'), cs.primary),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(loc.get('target_calories')),
                  const SizedBox(height: 4),
                  _sub(loc.get('goal_description')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '2000',
                      suffixText: loc.get('kcal'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveGoal,
                      icon: const Icon(Icons.flag_rounded),
                      label: Text(loc.get('set_goal')),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── TDEE Calculator ────────────────────────────────────────────
          _Label(loc.get('tdee_calculator'), cs.primary),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(loc.get('mifflin_formula')),
                  _sub(loc.get('tdee_description')),
                  const SizedBox(height: 16),

                  // Gender toggle
                  Row(
                    children: [
                      Expanded(
                          child: _GenderBtn(
                        label: loc.get('male'),
                        icon: Icons.male_rounded,
                        selected: _gender == Gender.male,
                        onTap: () =>
                            setState(() => _gender = Gender.male),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _GenderBtn(
                        label: loc.get('female'),
                        icon: Icons.female_rounded,
                        selected: _gender == Gender.female,
                        onTap: () =>
                            setState(() => _gender = Gender.female),
                      )),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Age / Weight / Height
                  Row(
                    children: [
                      Expanded(
                          child: _NumField(
                              ctrl: _ageCtrl,
                              label: loc.get('age'),
                              suffix: loc.get('yrs'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _NumField(
                              ctrl: _weightCtrl,
                              label: loc.get('weight'),
                              suffix: loc.get('kg'),
                              decimal: true)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _NumField(
                              ctrl: _heightCtrl,
                              label: loc.get('height'),
                              suffix: loc.get('cm'),
                              decimal: true)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Activity level
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: loc.get('activity_level'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ActivityLevel>(
                        value: _activity,
                        isExpanded: true,
                        items: ActivityLevel.values
                            .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                    _activityLabel(a, loc),
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _activity = v ?? _activity),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate_rounded),
                      label: Text(loc.get('calculate')),
                    ),
                  ),

                  if (_tdeeResult != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _TDEEResults(
                      result: _tdeeResult!,
                      onSetGoal: _applyTDEEGoal,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Data ───────────────────────────────────────────────────────
          _Label(loc.get('data'), cs.primary),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: Text(loc.get('clear_all_data'),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w500)),
              subtitle: Text(loc.get('clear_all_subtitle')),
              onTap: _clearData,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _activityLabel(ActivityLevel a, AppLocalizations loc) {
    return switch (a) {
      ActivityLevel.sedentary => loc.get('sedentary'),
      ActivityLevel.lightlyActive => loc.get('lightly_active'),
      ActivityLevel.moderatelyActive => loc.get('moderately_active'),
      ActivityLevel.veryActive => loc.get('very_active'),
      ActivityLevel.extraActive => loc.get('extra_active'),
    };
  }

  Widget _title(String t) => Text(t,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600));

  Widget _sub(String t) => Text(t,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
          ));
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.4,
              ),
        ),
      );
}

class _ThemeBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeBtn(
      {required this.label,
      this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            if (icon != null)
              Icon(icon,
                  size: 20,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.45)),
            if (icon != null) const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.65),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderBtn(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
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

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String suffix;
  final bool decimal;

  const _NumField(
      {required this.ctrl,
      required this.label,
      required this.suffix,
      this.decimal = false});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType:
            TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      );
}

// ── TDEE results ──────────────────────────────────────────────────────────────

class _TDEEResults extends StatelessWidget {
  final TDEEResult result;
  final void Function(int) onSetGoal;

  const _TDEEResults({required this.result, required this.onSetGoal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatBox(loc.get('bmr'), '${result.bmr}',
                loc.get('kcal_day_rest'), cs.secondary),
            const SizedBox(width: 8),
            _StatBox(loc.get('tdee'), '${result.tdee}',
                loc.get('total_daily'), cs.primary),
          ],
        ),
        const SizedBox(height: 12),
        Text(loc.get('suggested_goals'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _GoalRow(
          label: loc.get('lose_weight'),
          kcal: result.lossGoal,
          color: const Color(0xFF5C9E4A),
          icon: Icons.trending_down_rounded,
          onSet: () => onSetGoal(result.lossGoal),
          setGoalLabel: loc.get('set_goal'),
        ),
        const SizedBox(height: 6),
        _GoalRow(
          label: loc.get('maintain'),
          kcal: result.maintainGoal,
          color: const Color(0xFFE8622A),
          icon: Icons.trending_flat_rounded,
          onSet: () => onSetGoal(result.maintainGoal),
          setGoalLabel: loc.get('set_goal'),
        ),
        const SizedBox(height: 6),
        _GoalRow(
          label: loc.get('gain_weight'),
          kcal: result.gainGoal,
          color: const Color(0xFFF4A020),
          icon: Icons.trending_up_rounded,
          onSet: () => onSetGoal(result.gainGoal),
          setGoalLabel: loc.get('set_goal'),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _StatBox(this.label, this.value, this.sub, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                  overflow: TextOverflow.ellipsis),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(sub,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.50),
                      ),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _GoalRow extends StatelessWidget {
  final String label;
  final int kcal;
  final Color color;
  final IconData icon;
  final VoidCallback onSet;
  final String setGoalLabel;

  const _GoalRow({
    required this.label,
    required this.kcal,
    required this.color,
    required this.icon,
    required this.onSet,
    required this.setGoalLabel,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: color),
                    overflow: TextOverflow.ellipsis),
                Text('$kcal ${loc.get('kcal_day')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: color.withValues(alpha: 0.75)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(
            onPressed: onSet,
            style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(60, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(setGoalLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
