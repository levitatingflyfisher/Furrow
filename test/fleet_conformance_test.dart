import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

/// Furrow's recorded fleet posture — every deliberate divergence from
/// fleet canon lives in this one config, enforced as tests.
void main() => runFleetConformance(const FleetAppConfig(
      appId: 'furrow',
      // Furrow bundles Lora + Nunito, so there is no web-font fallback to
      // catch a character they cannot draw — C7 sweeps lib/ for any.
      // C8 — the review screen's count-cadence '+' now goes through
      // OhIconButton.filled (see icon_buttons.dart); this stops any new
      // bare IconButton.filled/.filledTonal in lib/ from reopening the
      // ohStyle/Flutter 3.38.7 iconTheme collision.
      checks: {...FleetAppConfig.withBundledFonts, FleetCheck.c8IconButtons},
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
