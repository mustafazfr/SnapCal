import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditSheet(
        meal: meal,
        onSave: (editedMeal) {
          Navigator.pop(context);
          onSave(editedMeal);
        },
      ),
    );
  }

  void _showCorrectionDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
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
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(ctx);
              onCorrect?.call(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(ctx);
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

            // ── Wrong food button ──
            if (onCorrect != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => _showCorrectionDialog(context),
                    icon: Icon(Icons.help_outline_rounded,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.45)),
                    label: Text(
                      loc.get('not_this_food'),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ── Action buttons ──
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _showEditSheet(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(52, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 20),
                ),
                const SizedBox(width: 10),
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

// ── Edit Sheet ────────────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final Meal meal;
  final void Function(Meal) onSave;

  const _EditSheet({required this.meal, required this.onSave});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _portionCtrl;
  late final TextEditingController _caloriesCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.meal.foodName);
    _portionCtrl = TextEditingController(text: widget.meal.portionSize);
    _caloriesCtrl =
        TextEditingController(text: widget.meal.calories.toString());
    _proteinCtrl =
        TextEditingController(text: widget.meal.protein.toStringAsFixed(1));
    _carbsCtrl =
        TextEditingController(text: widget.meal.carbs.toStringAsFixed(1));
    _fatCtrl =
        TextEditingController(text: widget.meal.fat.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final edited = Meal(
      id: widget.meal.id,
      foodName: _nameCtrl.text.trim(),
      portionSize: _portionCtrl.text.trim(),
      calories: int.tryParse(_caloriesCtrl.text.trim()) ?? widget.meal.calories,
      protein:
          double.tryParse(_proteinCtrl.text.trim()) ?? widget.meal.protein,
      carbs: double.tryParse(_carbsCtrl.text.trim()) ?? widget.meal.carbs,
      fat: double.tryParse(_fatCtrl.text.trim()) ?? widget.meal.fat,
      timestamp: widget.meal.timestamp,
      imagePath: widget.meal.imagePath,
      confidence: widget.meal.confidence,
      notes: widget.meal.notes,
    );
    widget.onSave(edited);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(loc.get('edit_values'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: loc.get('food_name')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _portionCtrl,
            decoration: InputDecoration(labelText: loc.get('portion_size')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _caloriesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: loc.get('calories'),
                    suffixText: 'kcal',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _proteinCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.get('protein'),
                    suffixText: 'g',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carbsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.get('carbs'),
                    suffixText: 'g',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fatCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.get('fat'),
                    suffixText: 'g',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(loc.get('cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
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
