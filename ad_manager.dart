import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdResult { notReady, earned, dismissed }

/// ============================================================================
///  ADMOB CONFIGURATION  -  READ THIS BEFORE PUBLISHING
/// ============================================================================
///  1. Set [useTestAds] = false  (line marked  <<< STEP 1 >>>)
///  2. Replace the 6 placeholder IDs under "PRODUCTION IDS" with your real
///     AdMob ad unit IDs                         (lines marked  <<< STEP 2 >>>)
///  3. Replace the AdMob APP ID in AndroidManifest.xml. In this repo it is set by
///     tools/patch_android.py  ->  search for  ADMOB_APP_ID  and change it there
///     (iOS: Info.plist key GADApplicationIdentifier).     <<< STEP 3 >>>
/// ============================================================================
class AdManager {
  // <<< STEP 1 >>>  set to false for release builds
  static const bool useTestAds = true;

  // ---------------- Official Google TEST ad units ----------------
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardIos = 'ca-app-pub-3940256099942544/1712485313';

  // ---------------- PRODUCTION IDS (replace!) ----------------
  static const _prodBannerAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/1111111111'; // <<< STEP 2 >>>
  static const _prodBannerIos = 'ca-app-pub-XXXXXXXXXXXXXXXX/2222222222'; // <<< STEP 2 >>>
  static const _prodInterAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/3333333333'; // <<< STEP 2 >>>
  static const _prodInterIos = 'ca-app-pub-XXXXXXXXXXXXXXXX/4444444444'; // <<< STEP 2 >>>
  static const _prodRewardAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/5555555555'; // <<< STEP 2 >>>
  static const _prodRewardIos = 'ca-app-pub-XXXXXXXXXXXXXXXX/6666666666'; // <<< STEP 2 >>>

  static bool get _android => Platform.isAndroid;

  static String get bannerId => useTestAds
      ? (_android ? _testBannerAndroid : _testBannerIos)
      : (_android ? _prodBannerAndroid : _prodBannerIos);
  static String get interstitialId => useTestAds
      ? (_android ? _testInterAndroid : _testInterIos)
      : (_android ? _prodInterAndroid : _prodInterIos);
  static String get rewardedId => useTestAds
      ? (_android ? _testRewardAndroid : _testRewardIos)
      : (_android ? _prodRewardAndroid : _prodRewardIos);

  static InterstitialAd? _inter;
  static RewardedAd? _rewarded;
  static bool _started = false;

  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      _started = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('AdMob init failed: $e');
    }
  }

  static void _loadInterstitial() {
    if (!_started) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _inter = ad,
        onAdFailedToLoad: (e) => _inter = null,
      ),
    );
  }

  static void _loadRewarded() {
    if (!_started) return;
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => _rewarded = null,
      ),
    );
  }

  /// Shows an interstitial (if one is loaded). Completes when it is closed, or immediately if none.
  static Future<void> showInterstitial() {
    final ad = _inter;
    if (ad == null) {
      _loadInterstitial();
      return Future.value();
    }
    _inter = null;
    final c = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        if (!c.isCompleted) c.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInterstitial();
        if (!c.isCompleted) c.complete();
      },
    );
    ad.show();
    return c.future;
  }

  /// Shows a rewarded video. Result: [AdResult.earned] only if the user earned the reward.
  static Future<AdResult> showRewarded() {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return Future.value(AdResult.notReady);
    }
    _rewarded = null;
    final c = Completer<AdResult>();
    bool earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!c.isCompleted) c.complete(earned ? AdResult.earned : AdResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        if (!c.isCompleted) c.complete(AdResult.notReady);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return c.future;
  }
}

/// Banner anchored at the bottom of a screen. Reserves its height so the layout never jumps.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: AdManager.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, e) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: _loaded && _ad != null
          ? Center(child: SizedBox(width: 320, height: 50, child: AdWidget(ad: _ad!)))
          : const SizedBox.shrink(),
    );
  }
}
