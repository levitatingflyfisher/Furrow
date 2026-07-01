import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

/// Furrow's recorded fleet posture — every deliberate divergence from
/// fleet canon lives in this one config, enforced as tests.
void main() => runFleetConformance(const FleetAppConfig(
      appId: 'furrow',
      // Tier T: canonical openhearth_design tokens + text ladder consumed
      // by sibling path; theme construction stays local.
      styleTier: StyleTier.tokens,
      // The exact permission surface, both directions. NO INTERNET is the
      // point of this app (the APK cannot phone home, structurally);
      // FOREGROUND_SERVICE_MEDIA_PLAYBACK was verified unexercised
      // (Sundial fork inheritance — no Dart caller) and removed.
      androidPermissions: {
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
      },
      // C4 v2 — the release MERGED surface: source permissions plus
      // what plugins and the manifest merge inject. Bites when an APK
      // build has left a merged manifest under build/ (dev box).
      mergedAndroidPermissions: {
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.VIBRATE',
        'android.permission.WAKE_LOCK',
        'com.openhearth.furrow.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
      },
    ));
