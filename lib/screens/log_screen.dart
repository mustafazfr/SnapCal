import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../services/health_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/meal_card.dart';
import '../widgets/progress_bar.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedDate = DateTime.now();
  List<Meal> _meals = [];
  bool _loading = true;
  int _steps = 0;
  bool _healthEnabled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final meals =
        await StorageService.instance.getMealsForDate(_selectedDate);

    // Load health data if enabled
    final healthOn = HealthService.instance.isEnabled;
    int steps = 0;
    if (healthOn) {
      steps = await HealthService.instance.getStepsForDate(_selectedDate);
    }

    if (!mounted) return;
    for (final m in meals) {
      debugPrint('[SnapCal] Loaded meal "${m.foodName}" imagePath: ${m.imagePath}');
      if (m.imagePath != null) {
        final exists = File(m.imagePath!).existsSync();
        debugPrint('[SnapCal]   → File exists: $exists');
      }
    }
    setState(() {
      _meals = meals;
      _healthEnabled = healthOn;
      _steps = steps;
      _loading = false;
    });
  }

  void _shift(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _loading = true;
    });
    _load();
  }

  void _goToday() {
    if (_isToday) return;
    setState(() {
      _selectedDate = DateTime.now();
      _loading = true;
    });
    _load();
  }

  Future<void> _delete(Meal meal) async {
    final loc = AppLocalizations.of(context);
    await StorageService.instance.deleteMeal(meal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.get('meal_deleted')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: loc.get('undo'),
          onPressed: () async {
            await StorageService.instance.saveMeal(meal);
            _load();
          },
        ),
      ),
    );
    _load();
  }

  Future<bool> _confirmDelete() async {
    final loc = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.get('delete_meal')),
            content: Text(loc.get('delete_meal_confirm')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.get('cancel'))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(loc.get('delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  int get _total => _meals.fold(0, (s, m) => s + m.calories);
  int get _goal => StorageService.instance.calorieGoal;
  int get _burned => HealthService.estimateCaloriesBurned(_steps);
  int get _net => _total - _burned;
  int get _remaining => _goal - _net;
  bool get _isToday => _sameDay(_selectedDate, DateTime.now());

  String get _dateLabel {
    final loc = AppLocalizations.of(context);
    if (_isToday) return loc.get('today');
    final yesterday =
        DateTime.now().subtract(const Duration(days: 1));
    if (_sameDay(_selectedDate, yesterday)) return loc.get('yesterday');
    return DateFormat('EEE, MMM d').format(_selectedDate);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Auto-refresh when health setting changed externally (e.g. from Settings tab)
    final currentHealthEnabled = HealthService.instance.isEnabled;
    if (currentHealthEnabled != _healthEnabled && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              centerTitle: true,
              title: Text(loc.get('meal_log'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  children: [
                    _DateRow(
                      label: _dateLabel,
                      isToday: _isToday,
                      onPrev: () => _shift(-1),
                      onNext: () => _shift(1),
                      onToday: _goToday,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CalorieProgressBar(
                            consumed: _total, goal: _goal),
                      ),
                    ),
                    if (_meals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _MacroRow(meals: _meals),
                    ],
                    if (_healthEnabled && _meals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CalorieBalanceCard(
                        eaten: _total,
                        burned: _burned,
                        steps: _steps,
                        goal: _goal,
                        net: _net,
                        remaining: _remaining,
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_meals.isEmpty)
              SliverFillRemaining(child: _Empty(isToday: _isToday))
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final meal = _meals[i];
                      return Dismissible(
                        key: Key(meal.id),
                        direction: DismissDirection.endToStart,
                        background: _DeleteBg(),
                        confirmDismiss: (_) => _confirmDelete(),
                        onDismissed: (_) => _delete(meal),
                        child: MealCard(meal: meal),
                      );
                    },
                    childCount: _meals.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Date navigation row ───────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final String label;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _DateRow({
    required this.label,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: isToday ? null : onToday,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isToday ? cs.primary : null,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (!isToday)
                  Text(
                    loc.get('tap_to_return'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.38),
                        ),
                  ),
              ],
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: isToday ? null : onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ],
    );
  }
}

// ── Macro summary chips ───────────────────────────────────────────────────────

class _MacroRow extends StatelessWidget {
  final List<Meal> meals;
  const _MacroRow({required this.meals});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final p = meals.fold<double>(0, (s, m) => s + m.protein);
    final c = meals.fold<double>(0, (s, m) => s + m.carbs);
    final f = meals.fold<double>(0, (s, m) => s + m.fat);
    return Row(
      children: [
        Expanded(child: _Chip(loc.get('protein'), p, const Color(0xFF5C9E4A))),
        const SizedBox(width: 8),
        Expanded(child: _Chip(loc.get('carbs'), c, const Color(0xFFE8622A))),
        const SizedBox(width: 8),
        Expanded(child: _Chip(loc.get('fat'), f, const Color(0xFFF4A020))),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(0)}g',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.75)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ── Calorie balance card ──────────────────────────────────────────────────────

class _CalorieBalanceCard extends StatelessWidget {
  final int eaten;
  final int burned;
  final int steps;
  final int goal;
  final int net;
  final int remaining;

  const _CalorieBalanceCard({
    required this.eaten,
    required this.burned,
    required this.steps,
    required this.goal,
    required this.net,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final isOver = remaining < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(Icons.balance_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  loc.get('calorie_balance'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Balance row: eaten - burned = net
            Row(
              children: [
                Expanded(
                  child: _BalanceItem(
                    icon: Icons.restaurant_rounded,
                    label: loc.get('eaten'),
                    value: '$eaten',
                    color: const Color(0xFFE8622A),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('−',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withValues(alpha: 0.35))),
                ),
                Expanded(
                  child: _BalanceItem(
                    icon: Icons.directions_walk_rounded,
                    label: '${loc.get('burned')} ($steps ${loc.get('steps')})',
                    value: '$burned',
                    color: const Color(0xFF5C9E4A),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('=',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withValues(alpha: 0.35))),
                ),
                Expanded(
                  child: _BalanceItem(
                    icon: Icons.track_changes_rounded,
                    label: loc.get('net'),
                    value: '$net',
                    color: cs.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            // Remaining message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isOver
                    ? Colors.red.withValues(alpha: 0.08)
                    : const Color(0xFF5C9E4A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOver
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: isOver
                        ? Colors.red.shade500
                        : const Color(0xFF5C9E4A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOver
                        ? loc
                            .get('you_are_over')
                            .replaceAll('%s', '${remaining.abs()}')
                        : loc
                            .get('you_can_eat_more')
                            .replaceAll('%s', '$remaining'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isOver
                              ? Colors.red.shade500
                              : const Color(0xFF5C9E4A),
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

class _BalanceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _BalanceItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color.withValues(alpha: 0.70),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Delete swipe background ───────────────────────────────────────────────────

class _DeleteBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 26),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final bool isToday;
  const _Empty({required this.isToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.no_food_rounded,
            size: 80, color: cs.primary.withValues(alpha: 0.18)),
        const SizedBox(height: 16),
        Text(
          isToday ? loc.get('no_meals_today') : loc.get('no_meals_this_day'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          isToday
              ? loc.get('analyze_to_start')
              : loc.get('navigate_other_day'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.32),
              ),
        ),
      ],
    );
  }
}
