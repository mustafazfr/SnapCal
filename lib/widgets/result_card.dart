import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../utils/app_localizations.dart';

/// Displays the Claude analysis result with animated calories, macro breakdown, and edit capability.
class ResultCard extends StatelessWidget {
  final Meal meal;
  final void Function(Meal meal) onSave;
  final void Function(String correction)? onCorrect;

  const ResultCard({
    super.key,
    required this.meal,
    required this.onSave,
    this.onCorrect,
  });

  static const _proteinColor = Color(0xFF5C9E4A);
  static const _carbsColor = Color(0xFFE8622A);
  static const _fatColor = Color(0xFFF4A020);

  Color _confidenceColor(String c) {
    return switch (c.toLowerCase()) {
      'high' => const Color(0xFF5C9E4A),
      'medium' => const Color(0xFFF4A020),
      _ => Colors.red.shade400,
    };
  }

  String _confidenceLabel(String c, AppLocalizations loc) {
    return switch (c.toLowerCase()) {
      'high' => loc.get('confidence_high'),
      'medium' => loc.get('confidence_medium'),
      _ => loc.get('confidence_low'),
    };
  }

  IconData _confidenceIcon(String c) {
    return switch (c.toLowerCase()) {
      'high' => Icons.verified_rounded,
      'medium' => Icons.info_rounded,
      _ => Icons.warning_rounded,
    };
  }

  void _showCorrectionDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('correct_food_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: loc.get('correct_food_hint'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              navigator.pop();
              onCorrect?.call(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: Text(loc.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                navigator.pop();
                onCorrect?.call(value);
              }
            },
            child: Text(loc.get('reanalyze')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final totalMacroGrams = meal.protein + meal.carbs + meal.fat;
    final confColor = _confidenceColor(meal.confidence);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: food name + confidence ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.restaurant_rounded,
                      color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.foodName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meal.portionSize.isNotEmpty)
                        Text(
                          meal.portionSize,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.50),
                                  ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_confidenceIcon(meal.confidence),
                          size: 13, color: confColor),
                      const SizedBox(width: 4),
                      Text(
                        _confidenceLabel(meal.confidence, loc),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: confColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Calorie display ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.08),
                    cs.primary.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: meal.calories),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) => Text(
                      '$val',
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                                height: 1,
                              ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('calories').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: cs.primary.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Macro chips ──
            Row(
              children: [
                _MacroChip(
                  label: loc.get('protein'),
                  grams: meal.protein,
                  total: totalMacroGrams,
                  color: _proteinColor,
                ),
                const SizedBox(width: 8),
                _MacroChip(
                  label: loc.get('carbs'),
                  grams: meal.carbs,
                  total: totalMacroGrams,
                  color: _carbsColor,
                ),
                const SizedBox(width: 8),
                _MacroChip(
                  label: loc.get('fat'),
                  grams: meal.fat,
                  total: totalMacroGrams,
                  color: _fatColor,
                ),
              ],
            ),

            // ── Macro bar (visual proportion) ──
            const SizedBox(height: 12),
            if (totalMacroGrams > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Row(
                      children: [
                        Expanded(
                          flex: (meal.protein * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _proteinColor),
                        ),
                        Expanded(
                          flex: (meal.carbs * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _carbsColor),
                        ),
                        Expanded(
                          flex: (meal.fat * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _fatColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ── Action buttons ──
            Row(
              children: [
                if (onCorrect != null)
                  OutlinedButton.icon(
                    onPressed: () => _showCorrectionDialog(context),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(loc.get('not_this_food')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(52, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                if (onCorrect != null) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onSave(meal),
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: Text(loc.get('save_to_log')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Macro Chip ───────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  final String label;
  final double grams;
  final double total;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.grams,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (grams / total * 100).round() : 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '${grams.toStringAsFixed(1)}g',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.80),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

