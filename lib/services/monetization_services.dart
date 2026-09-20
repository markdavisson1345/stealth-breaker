abstract interface class AdService {
  Future<bool> showRewardedAd({required String placement});
  Future<void> showInterstitial({required String placement});
}

class NoopAdService implements AdService {
  const NoopAdService();
  @override
  Future<bool> showRewardedAd({required String placement}) async => false;
  @override
  Future<void> showInterstitial({required String placement}) async {}
}

abstract interface class PurchaseService {
  Future<bool> purchase(String productId);
  Future<void> restorePurchases();
}

class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();
  @override
  Future<bool> purchase(String productId) async => false;
  @override
  Future<void> restorePurchases() async {}
}

abstract interface class EntitlementService {
  bool hasEntitlement(String id);
  Future<void> setEntitlement(String id, bool active);
}

class LocalEntitlementService implements EntitlementService {
  final Set<String> _active = {};
  @override
  bool hasEntitlement(String id) => _active.contains(id);
  @override
  Future<void> setEntitlement(String id, bool active) async {
    active ? _active.add(id) : _active.remove(id);
  }
}
