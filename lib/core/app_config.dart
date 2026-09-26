/// Central place for every value you need to change before release.
class AppConfig {
  static const String appName = 'Neon Flow';

  /// While true the app uses Google's official *test* ad unit IDs, which are
  /// always safe to click. Set to false (and fill in the IDs below) for release.
  static const bool useTestAds = true;

  // ---- Real AdMob ad units (create them in the AdMob console) -------------
  static const String bannerAdUnit = 'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB';
  static const String interstitialAdUnit = 'ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII';
  static const String rewardedAdUnit = 'ca-app-pub-XXXXXXXXXXXXXXXX/RRRRRRRRRR';

  // ---- Google's public test ad units (Android) ----------------------------
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String get banner => useTestAds ? _testBanner : bannerAdUnit;
  static String get interstitial => useTestAds ? _testInterstitial : interstitialAdUnit;
  static String get rewarded => useTestAds ? _testRewarded : rewardedAdUnit;

  // ---- Google Play Billing product IDs (consumables) ----------------------
  // Create these as "Managed products" in Play Console > Monetize > Products.
  static const String hints5 = 'hints_5';
  static const String hints20 = 'hints_20';
  static const String hints50 = 'hints_50';
  static const Map<String, int> hintPacks = {hints5: 5, hints20: 20, hints50: 50};

  /// Optional: URL of a JSON file to toggle monetisation remotely, e.g.
  /// {"adsEnabled":true,"bannerEnabled":true,"interstitialEnabled":true,
  ///  "rewardedEnabled":true,"iapEnabled":true,"interstitialEvery":3}
  /// Leave empty to only use the local toggles. Host it on any static site
  /// (GitHub Pages, Firebase Hosting, S3...).
  static const String remoteConfigUrl = '';

  static const int startingHints = 5;
  static const int rewardedHintAmount = 1;
}
