import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/meal.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/result_card.dart';
import '../widgets/shimmer_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _picker = ImagePicker();
  final _claude = ClaudeService();

  File? _image;
  bool _loading = false;
  Meal? _result;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  // ── Image picking ──────────────────────────────────────────────────────────

  void _showPickerSheet() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(loc.get('take_a_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(loc.get('choose_from_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final loc = AppLocalizations.of(context);
    try {
      final picked =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = null;
        _error = null;
      });
      // Auto-analyze after picking image (Usability improvement)
      _analyze();
    } catch (e) {
      setState(() => _error = loc.get('camera_error'));
    }
  }

  // ── Claude analysis ────────────────────────────────────────────────────────

  Future<void> _analyze({String? correction}) async {
    final image = _image;
    if (image == null) return;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final lang = AppLocalizations.of(context).language.name;
      final json = await _claude.analyzeImage(image, correction: correction, langCode: lang);
      if (!mounted) return;
      final meal = ClaudeService.mealFromJson(json, image.path);
      setState(() {
        _result = meal;
        _loading = false;
      });
    } on ClaudeException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _labeledError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).get('something_went_wrong');
      });
    }
  }

  String _labeledError(ClaudeException e) {
    final loc = AppLocalizations.of(context);
    return switch (e.kind) {
      ClaudeError.noApiKey => loc.get('error_no_api_key'),
      ClaudeError.invalidApiKey => loc.get('error_invalid_api_key'),
      ClaudeError.noInternet => loc.get('error_no_internet'),
      ClaudeError.rateLimited => loc.get('error_rate_limited'),
      ClaudeError.unrecognizedFood => loc.get('error_unrecognized_food'),
      ClaudeError.insufficientCredits => loc.get('error_insufficient_credits'),
      ClaudeError.unknown => e.message,
    };
  }

  // ── Save to log ────────────────────────────────────────────────────────────

  Future<void> _save(Meal meal) async {
    // Copy image from temp directory to permanent app storage
    var savedMeal = meal;
    if (_image != null && meal.imagePath != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final mealImagesDir = Directory('${appDir.path}/meal_images');
        if (!await mealImagesDir.exists()) {
          await mealImagesDir.create(recursive: true);
        }
        final ext = p.extension(_image!.path);
        final permanentPath = '${mealImagesDir.path}/${meal.id}$ext';
        await _image!.copy(permanentPath);
        savedMeal = meal.copyWith(imagePath: permanentPath);
      } catch (_) {
        // If copy fails, save meal without image
      }
    }

    await StorageService.instance.saveMeal(savedMeal);
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${meal.foodName} ${loc.get('saved_to_log')}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {
      _result = null;
      _image = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            centerTitle: false,
            title: Text(loc.get('app_title'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: loc.get('how_it_works'),
                  onPressed: _showHowItWorks,
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero upload zone
                _UploadZone(
                  image: _image,
                  onTap: _showPickerSheet,
                ),

                const SizedBox(height: 16),

                // Shimmer loading skeleton
                if (_loading) const ResultCardSkeleton(),

                // Error banner with retry button
                if (_error != null)
                  _ErrorBanner(
                    message: _error!,
                    onRetry: _image != null ? _analyze : null,
                  ),

                // Result card
                if (_result != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: ResultCard(
                      key: ValueKey(_result!.id),
                      meal: _result!,
                      onSave: _save,
                      onCorrect: (correction) =>
                          _analyze(correction: correction),
                    ),
                  ),

                // Empty hero hint
                if (_image == null && !_loading) _EmptyHint(cs: cs),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowItWorks() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.get('how_it_works')),
        content: Text(loc.get('how_it_works_text')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.get('got_it')))
        ],
      ),
    );
  }
}

// ── Upload zone ───────────────────────────────────────────────────────────────

class _UploadZone extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;

  const _UploadZone({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    if (image != null) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 180,
                  maxHeight: 320,
                ),
                color: cs.onSurface.withValues(alpha: 0.05),
                child: Hero(
                  tag: 'food_preview',
                  child: Image.file(
                    image!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: cs.surface.withValues(alpha: 0.90),
                  foregroundColor: cs.onSurface,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text(loc.get('change'),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: cs.primary.withValues(alpha: 0.30),
          radius: 20,
        ),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_a_photo_rounded,
                    size: 26, color: cs.primary),
              ),
              const SizedBox(height: 14),
              Text(
                loc.get('tap_to_add_photo'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                loc.get('camera_or_gallery'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.40),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 8.0;
    const dashSpace = 5.0;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorBanner({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: isDark ? Colors.red.shade300 : Colors.red.shade600,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color:
                        isDark ? Colors.red.shade200 : Colors.red.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(loc.get('retry')),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.red.shade300 : Colors.red.shade600,
                  side: BorderSide(
                    color:
                        isDark ? Colors.red.shade700 : Colors.red.shade300,
                  ),
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyHint({required this.cs});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _HintChip(
                  icon: Icons.camera_alt_rounded,
                  label: loc.get('take_photo')),
              _HintChip(
                  icon: Icons.auto_awesome_rounded,
                  label: loc.get('ai_analysis')),
              _HintChip(
                  icon: Icons.book_outlined,
                  label: loc.get('log_meal')),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            loc.get('powered_by'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.30),
                ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: cs.primary.withValues(alpha: 0.55), size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    );
  }
}
