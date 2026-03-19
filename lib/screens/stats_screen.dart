import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/health_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with AutomaticKeepAliveClientMixin {
  int _weekOffset = 0;
  Map<DateTime, int> _data = {};
  Map<DateTime, int> _stepsData = {};
  bool _healthEnabled = false;
  bool _loading = true;
  int? _touchedIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final base = DateTime(monday.year, monday.month, monday.day);
    return base.add(Duration(days: 7 * _weekOffset));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));
  bool get _isCurrentWeek => _weekOffset == 0;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final data =
        await StorageService.instance.getWeeklyCalories(_weekStart);

    // Load health data if enabled
    final healthOn = HealthService.instance.isEnabled;
    Map<DateTime, int> steps = {};
    if (healthOn) {
      steps = await HealthService.instance.getWeeklySteps(_weekStart);
    }

    if (!mounted) return;
    setState(() {
      _data = data;
      _stepsData = steps;
      _healthEnabled = healthOn;
      _loading = false;
      _touchedIndex = null;
    });
  }

  void _shiftWeek(int delta) {
    if (delta > 0 && _isCurrentWeek) return;
    setState(() => _weekOffset += delta);
    _load();
  }

  int get _goal => StorageService.instance.calorieGoal;

  List<int> get _values => List.generate(
      7, (i) => _data[_weekStart.add(Duration(days: i))] ?? 0);

  int get _daysLogged => _values.where((v) => v > 0).length;
  int get _avgCalories {
    final nonZero = _values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return 0;
    return nonZero.fold(0, (s, v) => s + v) ~/ nonZero.length;
  }

  int get _maxCalories => _values.fold(0, (a, b) => a > b ? a : b);
  int get _daysUnderGoal =>
      _values.where((v) => v > 0 && v <= _goal).length;

  // Health computed values
  List<int> get _stepValues => List.generate(
      7, (i) => _stepsData[_weekStart.add(Duration(days: i))] ?? 0);
  int get _avgSteps {
    final nonZero = _stepValues.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return 0;
    return nonZero.fold(0, (s, v) => s + v) ~/ nonZero.length;
  }

  int get _totalBurned => _stepValues.fold(
      0, (s, v) => s + HealthService.estimateCaloriesBurned(v));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Auto-refresh when health toggle changes (IndexedStack keeps state alive)
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
              title: Text(loc.get('statistics'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: _loading
                    ? const _LoadingSkeleton()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WeekRow(
                            weekStart: _weekStart,
                            weekEnd: _weekEnd,
                            isCurrent: _isCurrentWeek,
                            onPrev: () => _shiftWeek(-1),
                            onNext: () => _shiftWeek(1),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 20, 12, 8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 10),
                                    child: _Legend(),
                                  ),
                                  SizedBox(
                                    height: 220,
                                    child: _daysLogged == 0
                                        ? const _ChartEmpty()
                                        : _BarChart(
                                            values: _values,
                                            goal: _goal,
                                            touchedIndex: _touchedIndex,
                                            weekStart: _weekStart,
                                            onTouch: (i) => setState(
                                                () => _touchedIndex = i),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_daysLogged > 0) ...[
                            const SizedBox(height: 16),
                            _SectionTitle(loc.get('weekly_summary')),
                            const SizedBox(height: 8),
                            _SummaryGrid(
                              avg: _avgCalories,
                              max: _maxCalories,
                              daysLogged: _daysLogged,
                              daysUnder: _daysUnderGoal,
                              goal: _goal,
                            ),
                          ],
                          if (_healthEnabled) ...[
                            const SizedBox(height: 16),
                            _SectionTitle(loc.get('activity')),
                            const SizedBox(height: 8),
                            _ActivitySummary(
                              avgSteps: _avgSteps,
                              totalBurned: _totalBurned,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _SectionTitle(loc.get('daily_breakdown')),
                          const SizedBox(height: 8),
                          ..._buildDailyRows(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDailyRows() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final date = _weekStart.add(Duration(days: i));
      final steps = _healthEnabled ? _stepValues[i] : null;
      return _DayRow(
        dayLabel: days[i],
        date: date,
        calories: _values[i],
        goal: _goal,
        isToday: _sameDay(date, DateTime.now()),
        steps: steps,
      );
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _WeekRow extends StatelessWidget {
  final DateTime weekStart;
  final DateTime weekEnd;
  final bool isCurrent;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WeekRow({
    required this.weekStart,
    required this.weekEnd,
    required this.isCurrent,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final fmt = DateFormat('MMM d');
    final label = isCurrent
        ? loc.get('this_week')
        : '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? cs.primary : null,
                ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: isCurrent ? null : onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LDot(color: const Color(0xFF5C9E4A), label: loc.get('under_goal_legend')),
        _LDot(color: const Color(0xFFF4A020), label: loc.get('near_limit_legend')),
        _LDot(color: Colors.red.shade400, label: loc.get('over_goal_legend')),
      ],
    );
  }
}

class _LDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.60),
                  )),
        ],
      );
}

class _BarChart extends StatelessWidget {
  final List<int> values;
  final int goal;
  final int? touchedIndex;
  final DateTime weekStart;
  final void Function(int?) onTouch;

  const _BarChart({
    required this.values,
    required this.goal,
    required this.touchedIndex,
    required this.weekStart,
    required this.onTouch,
  });

  Color _color(int cal) {
    if (cal == 0) return Colors.grey.shade300;
    final r = cal / goal;
    if (r <= 0.9) return const Color(0xFF5C9E4A);
    if (r <= 1.0) return const Color(0xFFF4A020);
    return Colors.red.shade400;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final maxRaw = ([...values, goal]).reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw * 1.18;

    return BarChart(
      swapAnimationDuration: const Duration(milliseconds: 350),
      swapAnimationCurve: Curves.easeOutCubic,
      BarChartData(
        maxY: maxY.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.surfaceContainerHighest,
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, gIndex, rod, rodIndex) {
              const days = [
                'Monday', 'Tuesday', 'Wednesday',
                'Thursday', 'Friday', 'Saturday', 'Sunday'
              ];
              final cal = values[gIndex];
              if (cal == 0) return null;
              return BarTooltipItem(
                '${days[gIndex]}\n',
                TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontSize: 11),
                children: [
                  TextSpan(
                    text: '$cal kcal',
                    style: TextStyle(
                      color: _color(cal),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response?.spot == null) {
              onTouch(null);
              return;
            }
            onTouch(response!.spot!.touchedBarGroupIndex);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: (maxY / 4).ceilToDouble(),
              getTitlesWidget: (val, _) => Text(
                val >= 1000
                    ? '${(val / 1000).toStringAsFixed(1)}k'
                    : val.toInt().toString(),
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final idx = val.toInt();
                if (idx < 0 || idx > 6) return const SizedBox.shrink();
                final date = weekStart.add(Duration(days: idx));
                final isToday = _sameDay(date, DateTime.now());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[idx],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isToday
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).ceilToDouble(),
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.onSurface.withValues(alpha: 0.07),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goal.toDouble(),
              color: cs.onSurface.withValues(alpha: 0.30),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => loc.get('goal'),
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
        barGroups: List.generate(7, (i) {
          final cal = values[i];
          final touched = touchedIndex == i;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: cal == 0 ? 0.6 : cal.toDouble(),
                color: cal == 0
                    ? cs.onSurface.withValues(alpha: 0.07)
                    : _color(cal),
                width: touched ? 22 : 18,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY.toDouble(),
                  color: cs.onSurface.withValues(alpha: 0.03),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 56, color: cs.primary.withValues(alpha: 0.18)),
          const SizedBox(height: 10),
          Text(loc.get('no_meals_this_week'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.38),
                  )),
          const SizedBox(height: 4),
          Text(loc.get('log_meals_chart'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.28),
                  )),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int avg;
  final int max;
  final int daysLogged;
  final int daysUnder;
  final int goal;

  const _SummaryGrid({
    required this.avg,
    required this.max,
    required this.daysLogged,
    required this.daysUnder,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pct =
        daysLogged > 0 ? (daysUnder / daysLogged * 100).round() : 0;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      children: [
        _Tile(loc.get('daily_avg'), '$avg kcal', Icons.show_chart_rounded,
            const Color(0xFF5C9E4A)),
        _Tile(
            loc.get('highest_day'),
            '$max kcal',
            Icons.arrow_upward_rounded,
            max > goal ? Colors.red.shade400 : const Color(0xFFF4A020)),
        _Tile(loc.get('days_logged'), '$daysLogged / 7',
            Icons.calendar_today_rounded, const Color(0xFFE8622A)),
        _Tile(loc.get('under_goal'), '$pct${loc.get('of_days')}',
            Icons.emoji_events_rounded, const Color(0xFF5C9E4A)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Tile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: color.withValues(alpha: 0.75)),
                      overflow: TextOverflow.ellipsis),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DayRow extends StatelessWidget {
  final String dayLabel;
  final DateTime date;
  final int calories;
  final int goal;
  final bool isToday;
  final int? steps;

  const _DayRow({
    required this.dayLabel,
    required this.date,
    required this.calories,
    required this.goal,
    required this.isToday,
    this.steps,
  });

  Color _fill() {
    if (calories == 0) return Colors.grey.shade300;
    final r = calories / goal;
    if (r <= 0.9) return const Color(0xFF5C9E4A);
    if (r <= 1.0) return const Color(0xFFF4A020);
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final frac =
        goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isToday
            ? cs.primary.withValues(alpha: 0.07)
            : cs.surfaceContainerHighest.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(
                color: cs.primary.withValues(alpha: 0.22), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isToday
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.8),
                    )),
                Text(DateFormat('d').format(date),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.38))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor:
                        cs.onSurface.withValues(alpha: 0.08),
                    color: _fill(),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  calories == 0
                      ? loc.get('no_meals_logged')
                      : '$calories / $goal kcal',
                  style: TextStyle(
                      fontSize: 11,
                      color: calories == 0
                          ? cs.onSurface.withValues(alpha: 0.28)
                          : cs.onSurface.withValues(alpha: 0.55)),
                ),
                if (steps != null && steps! > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.directions_walk_rounded,
                          size: 12,
                          color: cs.onSurface.withValues(alpha: 0.40)),
                      const SizedBox(width: 3),
                      Text(
                        '${NumberFormat('#,###').format(steps)} ${loc.get('steps')}',
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.local_fire_department_rounded,
                          size: 12,
                          color: cs.onSurface.withValues(alpha: 0.40)),
                      const SizedBox(width: 2),
                      Text(
                        '${HealthService.estimateCaloriesBurned(steps!)} kcal',
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (calories > 0)
            Text('$calories',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _fill())),
        ],
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  final int avgSteps;
  final int totalBurned;

  const _ActivitySummary({
    required this.avgSteps,
    required this.totalBurned,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final fmt = NumberFormat('#,###');
    return Row(
      children: [
        Expanded(
          child: _Tile(
            loc.get('avg_steps'),
            '${fmt.format(avgSteps)} / day',
            Icons.directions_walk_rounded,
            const Color(0xFF4A9ECE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            loc.get('est_burned'),
            '${fmt.format(totalBurned)} kcal',
            Icons.local_fire_department_rounded,
            const Color(0xFFE8622A),
          ),
        ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.04, end: 0.13)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final shade = cs.onSurface.withValues(alpha: _a.value);
        const heights = [80.0, 140.0, 60.0, 170.0, 110.0, 80.0, 50.0];
        return Column(
          children: [
            Container(
                height: 48,
                decoration: BoxDecoration(
                    color: shade,
                    borderRadius: BorderRadius.circular(12))),
            const SizedBox(height: 16),
            Card(
              child: Container(
                height: 260,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    7,
                    (i) => Container(
                      width: 22,
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: shade,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
