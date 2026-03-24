import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Usage limits for free tier.
class FreeLimit {
  static const dailyAnalysis = 5;
  static const weeklyReports = 1;
}

class SubscriptionService extends ChangeNotifier {
  static final instance = SubscriptionService._();
  SubscriptionService._();

  bool _isPremium = false;
  CustomerInfo? _customerInfo;
  List<Package> _packages = [];

  bool get isPremium => _isPremium;
  List<Package> get packages => _packages;

  /// Call once at app startup.
  Future<void> init(String revenueCatApiKey) async {
    try {
      await Purchases.setLogLevel(LogLevel.error);
      final config = PurchasesConfiguration(revenueCatApiKey);
      await Purchases.configure(config);

      _customerInfo = await Purchases.getCustomerInfo();
      _isPremium = _checkPremium(_customerInfo!);

      Purchases.addCustomerInfoUpdateListener((info) {
        _customerInfo = info;
        _isPremium = _checkPremium(info);
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[SnapCal] RevenueCat init error: $e');
    }
  }

  /// Fetch available packages from RevenueCat.
  Future<void> fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current != null) {
        _packages = current.availablePackages;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SnapCal] Fetch offerings error: $e');
    }
  }

  /// Purchase a package.
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _isPremium = _checkPremium(result);
      notifyListeners();
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  /// Restore previous purchases.
  Future<bool> restore() async {
    try {
      final result = await Purchases.restorePurchases();
      _isPremium = _checkPremium(result);
      notifyListeners();
      return _isPremium;
    } catch (e) {
      debugPrint('[SnapCal] Restore error: $e');
      return false;
    }
  }

  bool _checkPremium(CustomerInfo info) {
    return info.entitlements.active.containsKey('premium');
  }
}
