import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../utils/app_localizations.dart';

/// Displays the Claude analysis result with animated calories, macro breakdown, and edit capability.
class ResultCard extends StatefulWidget {
  final Meal meal;
  final void Function(Meal meal) onSave;
  final void Function(String correction)? onCorrect;
  final VoidCallback? onDiscard;

  const ResultCard({
    super.key,
    required this.meal,
    required this.onSave,
    this.onCorrect,
    this.onDiscard,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  late Meal _meal;

  static const _proteinColor = Color(0xFF5C9E4A);
  static const _carbsColor = Color(0xFFE8622A);
  static const _fatColor = Color(0xFFF4A020);

  @override
  void initState() {
    super.initState();
    _meal = widget.meal;
  }

  @override
  void didUpdateWidget(ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal.id != widget.meal.id) {
      _meal = widget.meal;
    }
  }

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

  // "Yanlış mı?" dialog — yemek adı + porsiyon, ikisi de opsiyonel
  void _showCorrectionDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final portionCtrl = TextEditingController(text: _meal.portionSize);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('correct_food_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: loc.get('food_name'),
                hintText: loc.get('correct_food_hint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _submitCorrection(
                  navigator, nameCtrl.text, portionCtrl.text),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portionCtrl,
              decoration: InputDecoration(
                labelText: loc.get('portion_size'),
                hintText: '250g',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: Text(loc.get('cancel')),
          ),
          FilledButton(
            onPressed: () => _submitCorrection(
                navigator, nameCtrl.text, portionCtrl.text),
            child: Text(loc.get('reanalyze')),
          ),
        ],
      ),
    );
  }

  void _submitCorrection(
      NavigatorState navigator, String name, String portion) {
    final trimmedName = name.trim();
    final trimmedPortion = portion.trim();
    if (trimmedName.isEmpty && trimmedPortion.isEmpty) return;

    navigator.pop();

    // Her durumda Claude'a gönder — porsiyon değişince kalori de değişir
    final foodName = trimmedName.isNotEmpty ? trimmedName : _meal.foodName;
    final correction = trimmedPortion.isNotEmpty
        ? '$foodName, porsiyon: $trimmedPortion'
        : foodName;
    widget.onCorrect?.call(correction);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final totalMacroGrams = _meal.protein + _meal.carbs + _meal.fat;
    final confColor = _confidenceColor(_meal.confidence);

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
                        _meal.foodName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_meal.portionSize.isNotEmpty)
                        Text(
                          _meal.portionSize,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    cs.onSurface.withValues(alpha: 0.50),
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_confidenceIcon(_meal.confidence),
                          size: 13, color: confColor),
                      const SizedBox(width: 4),
                      Text(
                        _confidenceLabel(_meal.confidence, loc),
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
                    tween: IntTween(begin: 0, end: _meal.calories),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) => Text(
                      '$val',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
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
                  grams: _meal.protein,
                  total: totalMacroGrams,
                  color: _proteinColor,
                ),
                const SizedBox(width: 8),
                _MacroChip(
                  label: loc.get('carbs'),
                  grams: _meal.carbs,
                  total: totalMacroGrams,
                  color: _carbsColor,
                ),
                const SizedBox(width: 8),
                _MacroChip(
                  label: loc.get('fat'),
                  grams: _meal.fat,
                  total: totalMacroGrams,
                  color: _fatColor,
                ),
              ],
            ),

            // ── Macro bar ──
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
                          flex: (_meal.protein * 100 * v)
                              .round()
                              .clamp(1, 10000),
                          child: Container(color: _proteinColor),
                        ),
                        Expanded(
                          flex: (_meal.carbs * 100 * v)
                              .round()
                              .clamp(1, 10000),
                          child: Container(color: _carbsColor),
                        ),
                        Expanded(
                          flex:
                              (_meal.fat * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _fatColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ── Action buttons ──
            if (widget.onCorrect != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCorrectionDialog(context),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(loc.get('not_this_food')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onSave(_meal),
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: Text(loc.get('save_to_log')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            if (widget.onDiscard != null) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onDiscard,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor:
                        cs.onSurface.withValues(alpha: 0.50),
                  ),
                  child: Text(loc.get('cancel')),
                ),
              ),
            ],
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
