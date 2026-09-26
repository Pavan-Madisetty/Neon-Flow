import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_config.dart';
import 'monetization_config.dart';

/// Wraps AdMob: consent (UMP), interstitials and rewarded ads. Banner ads
/// are created by the BannerAdWidget. Every entry point checks the runtime
/// [MonetizationConfig] so ads can be disabled without a new release.
class AdService {
  final MonetizationConfig config;
  AdService(this.config);

  bool _initialised = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  bool get isReady => _initialised;
  bool get rewardedReady => _rewarded != null;

  Future<void> init() async {
    try {
      await _gatherConsent();
      await MobileAds.instance.initialize();
      _initialised = true;
      preload();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  /// Google's User Messaging Platform (GDPR/EEA consent form).
  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (error != null) debugPrint('Consent form error: ${error.message}');
            if (!completer.isCompleted) completer.complete();
          });
        } catch (e) {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint('Consent info error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  void preload() {
    if (!_initialised) return;
    if (config.interstitialEnabled) _loadInterstitial();
    if (config.rewardedEnabled) _loadRewarded();
  }

  // ------------------------------------------------------------ interstitial

  void _loadInterstitial() {
    if (_interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed: ${err.message}');
          _loadingInterstitial = false;
        },
      ),
    );
  }

  /// Shows an interstitial if enabled and loaded. Completes when it is
  /// dismissed (or immediately if nothing was shown). Returns whether shown.
  Future<bool> showInterstitial() async {
    if (!_initialised || !config.interstitialEnabled) return false;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    ad.show();
    return done.future;
  }

  // ---------------------------------------------------------------- rewarded

  void _loadRewarded() {
    if (_rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AppConfig.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded failed: ${err.message}');
          _loadingRewarded = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad. Returns true only if the user earned the reward.
  Future<bool> showRewarded() async {
    if (!_initialised || !config.rewardedEnabled) return false;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (view, reward) => earned = true);
    return done.future;
  }
}
