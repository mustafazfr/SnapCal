import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // New analysis result → reset local meal
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
              widget.onCorrect?.call(value.trim());
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
                widget.onCorrect?.call(value);
              }
            },
            child: Text(loc.get('reanalyze')),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditMealSheet(
        meal: _meal,
        onSave: (edited) => setState(() => _meal = edited),
      ),
    );
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_meal.portionSize.isNotEmpty)
                        Text(
                          _meal.portionSize,
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
                          flex: (_meal.protein * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _proteinColor),
                        ),
                        Expanded(
                          flex: (_meal.carbs * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _carbsColor),
                        ),
                        Expanded(
                          flex: (_meal.fat * 100 * v).round().clamp(1, 10000),
                          child: Container(color: _fatColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ── Secondary action buttons (Wrong food? / Edit) ──
            Row(
              children: [
                if (widget.onCorrect != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCorrectionDialog(context),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(loc.get('not_this_food'),
                          style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                if (widget.onCorrect != null) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditSheet(context),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(loc.get('edit_values'),
                        style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Primary save button ──
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

            // ── Discard button ──
            if (widget.onDiscard != null) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onDiscard,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: cs.onSurface.withValues(alpha: 0.50),
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

// ── Edit Meal Bottom Sheet ────────────────────────────────────────────────────

class _EditMealSheet extends StatefulWidget {
  final Meal meal;
  final void Function(Meal edited) onSave;

  const _EditMealSheet({required this.meal, required this.onSave});

  @override
  State<_EditMealSheet> createState() => _EditMealSheetState();
}

class _EditMealSheetState extends State<_EditMealSheet> {
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
    _proteinCtrl = TextEditingController(
        text: widget.meal.protein.toStringAsFixed(1));
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
    final edited = widget.meal.copyWith(
      foodName: _nameCtrl.text.trim().isEmpty
          ? widget.meal.foodName
          : _nameCtrl.text.trim(),
      portionSize: _portionCtrl.text.trim(),
      calories: int.tryParse(_caloriesCtrl.text) ?? widget.meal.calories,
      protein: double.tryParse(_proteinCtrl.text) ?? widget.meal.protein,
      carbs: double.tryParse(_carbsCtrl.text) ?? widget.meal.carbs,
      fat: double.tryParse(_fatCtrl.text) ?? widget.meal.fat,
    );
    Navigator.pop(context);
    widget.onSave(edited);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.get('edit_values'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Food name
          _EditField(
            controller: _nameCtrl,
            label: loc.get('food_name'),
            icon: Icons.restaurant_rounded,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),

          // Portion size
          _EditField(
            controller: _portionCtrl,
            label: loc.get('portion_size'),
            icon: Icons.scale_rounded,
            hint: '250g',
          ),
          const SizedBox(height: 12),

          // Calories
          _EditField(
            controller: _caloriesCtrl,
            label: '${loc.get('calories')} (kcal)',
            icon: Icons.local_fire_department_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),

          // Macros row
          Row(
            children: [
              Expanded(
                child: _EditField(
                  controller: _proteinCtrl,
                  label: '${loc.get('protein')} (g)',
                  icon: Icons.circle,
                  iconColor: const Color(0xFF5C9E4A),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditField(
                  controller: _carbsCtrl,
                  label: '${loc.get('carbs')} (g)',
                  icon: Icons.circle,
                  iconColor: const Color(0xFFE8622A),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditField(
                  controller: _fatCtrl,
                  label: '${loc.get('fat')} (g)',
                  icon: Icons.circle,
                  iconColor: const Color(0xFFF4A020),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(loc.get('save_changes')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.iconColor,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon,
            size: 18, color: iconColor ?? cs.onSurface.withValues(alpha: 0.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
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
