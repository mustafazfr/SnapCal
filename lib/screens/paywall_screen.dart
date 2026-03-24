import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import '../utils/app_localizations.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SubscriptionService.instance.fetchOfferings();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _purchase(Package pkg) async {
    setState(() => _purchasing = true);
    try {
      final success = await SubscriptionService.instance.purchase(pkg);
      if (!mounted) return;
      if (success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    try {
      final success = await SubscriptionService.instance.restore();
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'No active subscriptions found.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final packages = SubscriptionService.instance.packages;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            centerTitle: true,
            title: Text(loc.get('premium'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.get('premium_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.get('premium_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.60)),
                ),
                const SizedBox(height: 24),

                // Feature comparison
                _FeatureList(),

                const SizedBox(height: 24),

                // Packages
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (packages.isEmpty)
                  Center(
                    child: Text(loc.get('premium_unavailable'),
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.50))),
                  )
                else
                  ...packages.map((pkg) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PackageCard(
                          package: pkg,
                          onTap: _purchasing ? null : () => _purchase(pkg),
                        ),
                      )),

                if (_purchasing) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.error, fontSize: 13)),
                ],

                const SizedBox(height: 16),

                // Restore button
                Center(
                  child: TextButton(
                    onPressed: _purchasing ? null : _restore,
                    child: Text(loc.get('restore_purchase'),
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.50))),
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

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final features = [
      (loc.get('feature_analysis'), '5 / ${loc.get('day')}', loc.get('unlimited')),
      (loc.get('feature_report'), '1 / ${loc.get('week')}', loc.get('unlimited')),
      (loc.get('feature_water'), '✓', '✓'),
      (loc.get('feature_steps'), '✓', '✓'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                Expanded(
                  child: Text(loc.get('free'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Expanded(
                  child: Text(loc.get('premium'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...features.map((f) => _FeatureRow(
                label: f.$1,
                free: f.$2,
                premium: f.$3,
              )),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final String free;
  final String premium;
  const _FeatureRow(
      {required this.label, required this.free, required this.premium});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(label,
                  style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Text(free,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.50))),
          ),
          Expanded(
            child: Text(premium,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.primary)),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback? onTap;

  const _PackageCard({required this.package, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isYearly = package.packageType == PackageType.annual;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isYearly
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isYearly ? cs.primary : cs.outline.withValues(alpha: 0.20),
            width: isYearly ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isYearly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppLocalizations.of(context).get('best_value'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (isYearly) const SizedBox(height: 4),
                  Text(
                    package.storeProduct.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    package.storeProduct.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isYearly ? cs.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
