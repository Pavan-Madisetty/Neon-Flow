import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Runtime switches for every monetisation feature. Values are persisted,
/// can be flipped from Settings > Monetisation (long-press the version), and
/// can optionally be overridden remotely via [AppConfig.remoteConfigUrl].
class MonetizationConfig extends ChangeNotifier {
  static const _k = 'mon_';

  bool _ads = true;
  bool _banner = true;
  bool _interstitial = true;
  bool _rewarded = true;
  bool _iap = true;
  int _interstitialEvery = 3;

  /// Master switch for all ads.
  bool get adsEnabled => _ads;
  bool get bannerEnabled => _ads && _banner;
  bool get interstitialEnabled => _ads && _interstitial;
  bool get rewardedEnabled => _ads && _rewarded;
  bool get iapEnabled => _iap;
  int get interstitialEvery => _interstitialEvery;

  // Raw values for the settings UI.
  bool get rawAds => _ads;
  bool get rawBanner => _banner;
  bool get rawInterstitial => _interstitial;
  bool get rawRewarded => _rewarded;

  late SharedPreferences _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _ads = _prefs.getBool('${_k}ads') ?? true;
    _banner = _prefs.getBool('${_k}banner') ?? true;
    _interstitial = _prefs.getBool('${_k}interstitial') ?? true;
    _rewarded = _prefs.getBool('${_k}rewarded') ?? true;
    _iap = _prefs.getBool('${_k}iap') ?? true;
    _interstitialEvery = _prefs.getInt('${_k}every') ?? 3;
    notifyListeners();
    unawaited(fetchRemote());
  }

  Future<void> _save() async {
    await _prefs.setBool('${_k}ads', _ads);
    await _prefs.setBool('${_k}banner', _banner);
    await _prefs.setBool('${_k}interstitial', _interstitial);
    await _prefs.setBool('${_k}rewarded', _rewarded);
    await _prefs.setBool('${_k}iap', _iap);
    await _prefs.setInt('${_k}every', _interstitialEvery);
  }

  void setAds(bool v) => _update(() => _ads = v);
  void setBanner(bool v) => _update(() => _banner = v);
  void setInterstitial(bool v) => _update(() => _interstitial = v);
  void setRewarded(bool v) => _update(() => _rewarded = v);
  void setIap(bool v) => _update(() => _iap = v);
  void setInterstitialEvery(int v) => _update(() => _interstitialEvery = v.clamp(1, 20));

  void _update(VoidCallback change) {
    change();
    _save();
    notifyListeners();
  }

  /// Pulls the optional remote JSON. Failures are silent: local values stay.
  Future<void> fetchRemote() async {
    final url = AppConfig.remoteConfigUrl;
    if (url.isEmpty) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      bool? b(String key) => j[key] is bool ? j[key] as bool : null;
      _ads = b('adsEnabled') ?? _ads;
      _banner = b('bannerEnabled') ?? _banner;
      _interstitial = b('interstitialEnabled') ?? _interstitial;
      _rewarded = b('rewardedEnabled') ?? _rewarded;
      _iap = b('iapEnabled') ?? _iap;
      if (j['interstitialEvery'] is int) {
        _interstitialEvery = (j['interstitialEvery'] as int).clamp(1, 20);
      }
      await _save();
      notifyListeners();
      client.close();
    } catch (e) {
      debugPrint('Remote config unavailable: $e');
    }
  }
}
