import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

/// Furrow's recorded fleet posture — every deliberate divergence from
/// fleet canon lives in this one config, enforced as tests.
void main() => runFleetConformance(const FleetAppConfig(
      appId: 'furrow',
      // Furrow bundles Lora + Nunito via openhearth_design's package fonts,
      // so there is no web-font fallback to catch a character they cannot
      // draw — C7 sweeps lib/ for any.
      // C8 — the review screen's count-cadence '+' now goes through
      // OhIconButton.filled (see icon_buttons.dart); this stops any new
      // bare IconButton.filled/.filledTonal in lib/ from reopening the
      // ohStyle/Flutter 3.38.7 iconTheme collision.
      checks: {
        // C13: the PWA loads nothing from Google's CDNs. web/flutter_bootstrap.js
        // points CanvasKit and the engine's fallback fonts at this origin.
        FleetCheck.c13WebSelfHosted,
        ...FleetAppConfig.withBundledFonts,
        FleetCheck.c8IconButtons,
        // C10: no raw exception text on screen; failures go through
        // OhErrorState, the exception only behind Details.
        FleetCheck.c10RawErrors,
        // C11, strict: every top-bar action shows its word (OhBarAction /
        // OhBarOverflow); a tooltip is not a name.
        FleetCheck.c11StrictBarLabels,
        // C9: every routed screen has a way in.
        FleetCheck.c9Routes,
        // C12: the ochre accent stays at least CIEDE2000 12 from the
        // urgency red (errors also carry an icon and a word).
        FleetCheck.c12AccentVsError,
        // C5-primaryScreens: these screens run the 360dp x 1.3 sweep in
        // test/a11y/primary_action_sweep_test.dart.
        FleetCheck.c5PrimaryScreens,
      },
      primaryActionScreens: {'TodayScreen', 'HabitEditSheet'},
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
