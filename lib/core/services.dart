import 'ad_service.dart';
import 'audio_service.dart';
import 'iap_service.dart';
import 'level.dart';
import 'monetization_config.dart';
import 'progress_store.dart';

/// Simple service locator, initialised once in main().
class Services {
  static late final LevelRepository levels;
  static late final ProgressStore progress;
  static late final MonetizationConfig monetization;
  static late final AudioService audio;
  static late final AdService ads;
  static late final IapService iap;

  static Future<void> init() async {
    levels = await LevelRepository.load();
    progress = ProgressStore();
    await progress.load();
    progress.difficultyStarts = {
      for (final d in Difficulty.values)
        levels.levels.firstWhere((l) => l.difficulty == d).id,
    };
    monetization = MonetizationConfig();
    await monetization.load();
    audio = AudioService(progress);
    ads = AdService(monetization);
    iap = IapService(progress);
  }

  /// Slow, network-dependent services start after the first frame.
  static Future<void> initBackground() async {
    await audio.init();
    await ads.init();
    await iap.init();
  }
}
