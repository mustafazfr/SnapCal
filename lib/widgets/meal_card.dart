import 'dart:io';
import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../services/storage_service.dart';

/// Compact card shown in the Log screen list.
class MealCard extends StatelessWidget {
  final Meal meal;

  const MealCard({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                Hero(
                  tag: 'meal_image_${meal.id}',
                  child: _Thumbnail(imagePath: meal.imagePath),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.foodName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meal.portionSize,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.50),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right side
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${meal.calories}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                    ),
                    Text(
                      'kcal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meal.formattedTime,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.40),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MealDetailSheet(meal: meal),
    );
  }
}

// ── Detail bottom sheet ────────────────────────────────────────────────────────

class _MealDetailSheet extends StatelessWidget {
  final Meal meal;
  const _MealDetailSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Hero image (large)
          if (meal.imagePath != null)
            Builder(builder: (context) {
              final resolved = StorageService.instance.resolveImagePath(meal.imagePath);
              if (resolved == null || !File(resolved).existsSync()) {
                return const SizedBox.shrink();
              }
              return Hero(
                tag: 'meal_image_${meal.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(resolved),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),
          Text(
            meal.foodName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${meal.formattedTime}  ·  ${meal.portionSize}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
          ),

          const SizedBox(height: 16),

          // Calorie banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '${meal.calories}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                        height: 1,
                      ),
                ),
                Text(
                  'calories',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary.withValues(alpha: 0.70),
                        letterSpacing: 1,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Macro chips
          Row(
            children: [
              _MacroChip(
                  label: 'Protein',
                  value: meal.protein,
                  color: const Color(0xFF5C9E4A)),
              const SizedBox(width: 8),
              _MacroChip(
                  label: 'Carbs',
                  value: meal.carbs,
                  color: const Color(0xFFE8622A)),
              const SizedBox(width: 8),
              _MacroChip(
                  label: 'Fat',
                  value: meal.fat,
                  color: const Color(0xFFF4A020)),
            ],
          ),

          if (meal.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: cs.onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meal.notes,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(1)}g',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String? imagePath;
  const _Thumbnail({this.imagePath});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = StorageService.instance.resolveImagePath(imagePath);
    final fileExists = resolved != null && File(resolved).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: fileExists
          ? Image.file(
              File(resolved),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            )
          : Container(
              width: 56,
              height: 56,
              color: cs.primary.withValues(alpha: 0.08),
              child: Icon(Icons.restaurant_rounded,
                  size: 28,
                  color: cs.primary.withValues(alpha: 0.35)),
            ),
    );
  }
}
