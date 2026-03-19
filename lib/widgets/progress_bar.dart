import 'package:flutter/material.dart';

/// Animated calorie progress bar used in both the Log screen and Home screen.
class CalorieProgressBar extends StatelessWidget {
  final int consumed;
  final int goal;

  const CalorieProgressBar({
    super.key,
    required this.consumed,
    required this.goal,
  });

  double get _fraction => goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

  Color _barColor() {
    final ratio = goal > 0 ? consumed / goal : 0.0;
    if (ratio < 0.75) return const Color(0xFF5C9E4A);
    if (ratio < 1.0) return const Color(0xFFF4A020);
    return Colors.red.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = goal - consumed;
    final isOver = consumed > goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$consumed kcal',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _barColor(),
                  ),
            ),
            Text(
              'Goal: $goal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.50),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              color: _barColor(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isOver
              ? '${consumed - goal} kcal over goal'
              : '$remaining kcal remaining',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isOver
                    ? Colors.red.shade500
                    : cs.onSurface.withValues(alpha: 0.55),
              ),
        ),
      ],
    );
  }
}
