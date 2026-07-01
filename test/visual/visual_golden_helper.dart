import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Named logical device sizes for responsive golden sweeps.
///
/// Rendering one widget at several viewport sizes captures layout reflow
/// (responsiveness) as separate golden PNGs that can be inspected directly.
const Map<String, Size> kResponsiveSizes = <String, Size>{
  'phone': Size(360, 740),
  'tablet': Size(768, 1024),
  'desktop': Size(1280, 800),
};

/// Renders [home] at every combination of [sizes] × [textScales] (logical px,
/// dpr 1.0) and writes/compares one golden PNG per combination under
/// `test/visual/goldens/`.
///
/// [home] is the screen/widget content (it becomes `MaterialApp.home`); the
/// helper supplies the `MaterialApp` and injects the text scale via the app
/// builder so it actually reaches the content (a `MediaQuery` placed *above*
/// `MaterialApp` is ignored, because the app rebuilds its own from the view).
///
/// [textScales] sweeps accessibility font scaling — the axis most likely to
/// surface overflow on a mobile app. A single default scale leaves filenames
/// unchanged; multiple scales append a `_tsN.N` suffix.
///
/// Run `flutter test --update-goldens` to (re)generate, then read the PNGs
/// (montage with contact-sheet.sh) to inspect layout.
Future<void> goldenAtSizes(
  WidgetTester tester, {
  required String name,
  required Widget home,
  Map<String, Size> sizes = kResponsiveSizes,
  List<double> textScales = const <double>[1.0],
  ThemeData? theme,
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1.0;

  for (final MapEntry<String, Size> size in sizes.entries) {
    for (final double scale in textScales) {
      tester.view.physicalSize = size.value;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ));
      await tester.pumpAndSettle();
      final String scaleTag =
          textScales.length > 1 ? '_ts${scale.toStringAsFixed(1)}' : '';
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_${size.key}$scaleTag.png'),
      );
    }
  }

  // Drift schedules a zero-duration Timer when a query stream loses its last
  // listener (StreamQueryStore.markAsClosed), which happens when riverpod's
  // StreamProviders dispose as the tree unmounts. Left to the framework's
  // END-of-test unmount, that timer is created after the last pump and every
  // otherwise-green golden test dies with "A Timer is still pending" (then
  // wedges the runner shutting down). Unmount here and pump once so the
  // timer fires inside the test body instead. The pump needs an explicit
  // duration: only an elapsing pump fires due timers on the test's fake
  // clock (a plain pump() just flushes microtasks).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
