import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_config.dart';
import 'progress_store.dart';

/// Google Play Billing for consumable hint packs.
///
/// NOTE: purchases are delivered client-side. For a production game with real
/// money at stake, verify purchase tokens on your own server.
class IapService extends ChangeNotifier {
  final ProgressStore progress;
  IapService(this.progress);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool available = false;
  bool loading = true;
  List<ProductDetails> products = [];
  String? lastMessage;

  Future<void> init() async {
    try {
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('Purchase stream error: $e'),
      );
      available = await _iap.isAvailable();
      if (available) {
        final resp = await _iap.queryProductDetails(AppConfig.hintPacks.keys.toSet());
        products = resp.productDetails
          ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      }
    } catch (e) {
      debugPrint('IAP init failed: $e');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    if (!available) return;
    try {
      final param = PurchaseParam(productDetails: product);
      // autoConsume is true by default on Android: the pack can be re-bought.
      await _iap.buyConsumable(purchaseParam: param);
    } catch (e) {
      lastMessage = 'Purchase could not be started.';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          lastMessage = 'Purchase failed. You were not charged.';
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final amount = AppConfig.hintPacks[p.productID] ?? 0;
          if (amount > 0 && p.status == PurchaseStatus.purchased) {
            await progress.addHints(amount);
            lastMessage = '+$amount hints added!';
          }
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
      }
    }
    notifyListeners();
  }

  int hintsFor(ProductDetails p) => AppConfig.hintPacks[p.id] ?? 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
