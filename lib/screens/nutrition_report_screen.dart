import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/nutrition_report_service.dart';
import '../utils/app_localizations.dart';

class NutritionReportScreen extends StatelessWidget {
  final NutritionReport report;

  const NutritionReportScreen({super.key, required this.report});

  static const _proteinColor = Color(0xFF5C9E4A);
  static const _carbsColor = Color(0xFFE8622A);
  static const _fatColor = Color(0xFFF4A020);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final fmt = DateFormat('d MMM');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            centerTitle: false,
            title: Text(loc.get('ai_nutrition_report'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: loc.get('retry'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Period header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fmt.format(report.start)} – ${fmt.format(report.end)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${report.loggedDays} / ${report.totalDays} ${loc.get('days_logged')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.analytics_rounded,
                          color: cs.primary, size: 32),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Macro summary row
                Row(
                  children: [
                    _StatChip(
                      label: loc.get('daily_avg'),
                      value: '${report.avgCalories} kcal',
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: loc.get('protein'),
                      value: '${report.avgProtein.toStringAsFixed(0)}g',
                      color: _proteinColor,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: loc.get('carbs'),
                      value: '${report.avgCarbs.toStringAsFixed(0)}g',
                      color: _carbsColor,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: loc.get('fat'),
                      value: '${report.avgFat.toStringAsFixed(0)}g',
                      color: _fatColor,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // AI report text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.auto_awesome_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            loc.get('ai_analysis'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        report.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              color: cs.onSurface.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.70)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
