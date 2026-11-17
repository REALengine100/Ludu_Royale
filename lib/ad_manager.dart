import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdResult { notReady, earned, dismissed }

/// Master switch for ALL ads (app launch, next game, menu banner, rewarded video).
/// Set to false to turn every ad off.
const bool kAdsEnabled = true;

/// ============================================================================
///  ADMOB CONFIGURATION
/// ============================================================================
///  No code edit is needed to go live. The IDs come from GitHub secrets at build
///  time (see build.yml). Without them the app safely shows Google TEST ads.
///
///  GitHub -> Settings -> Secrets and variables -> Actions:
///    ADMOB_APP_ID           ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY   (App ID)
///    ADMOB_PROD             true                                      (turns real ads on)
///    ADMOB_BANNER_ID        ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
///    ADMOB_INTERSTITIAL_ID  ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
///    ADMOB_REWARDED_ID      ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN   (optional)
/// ============================================================================
class AdManager {
  // Real Ludo Royale ad units (AdMob). Set _useRealAds to false to go back to Google test ads.
  static const bool _useRealAds = true;
  static const bool _prod = _useRealAds || bool.fromEnvironment('ADMOB_PROD', defaultValue: false);
  static const String _prodBanner = 'ca-app-pub-3567057759843449/9535660266';
  static const String _prodInter = 'ca-app-pub-3567057759843449/4550926893';
  static const String _prodReward = 'ca-app-pub-3567057759843449/6957598387';

  // ---------------- Official Google TEST ad units ----------------
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardIos = 'ca-app-pub-3940256099942544/1712485313';

  static bool get _android => Platform.isAndroid;

  /// true while Google test ads are used (no secrets set yet).
  static bool get useTestAds => !(_prod && _android);

  static String _pick(String prodId, String testAndroid, String testIos) {
    if (useTestAds || prodId.isEmpty) return _android ? testAndroid : testIos;
    return prodId;
  }

  static String get bannerId => _pick(_prodBanner, _testBannerAndroid, _testBannerIos);
  static String get interstitialId => _pick(_prodInter, _testInterAndroid, _testInterIos);
  static String get rewardedId => _pick(_prodReward, _testRewardAndroid, _testRewardIos);

  static InterstitialAd? _inter;
  static RewardedAd? _rewarded;
  static bool _started = false;
  static int _interTries = 0;
  static int _rewardTries = 0;

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
    if (!_started || _inter != null) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _inter = ad;
          _interTries = 0;
        },
        onAdFailedToLoad: (e) {
          _inter = null;
          // retry with growing delay (30s, 60s, 90s ... max 5 tries)
          if (++_interTries <= 5) Future.delayed(Duration(seconds: 30 * _interTries), _loadInterstitial);
        },
      ),
    );
  }

  static void _loadRewarded() {
    if (!_started || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardTries = 0;
        },
        onAdFailedToLoad: (e) {
          _rewarded = null;
          if (++_rewardTries <= 5) Future.delayed(Duration(seconds: 30 * _rewardTries), _loadRewarded);
        },
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
/// Retries automatically if the first load fails (better fill rate = more income).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  int _tries = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad?.dispose();
    _loaded = false;
    _ad = BannerAd(
      adUnitId: AdManager.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _tries = 0;
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, e) {
          ad.dispose();
          _ad = null;
          if (mounted && ++_tries <= 5) {
            _retry = Timer(Duration(seconds: 20 * _tries), () {
              if (mounted) _load();
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _retry?.cancel();
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
