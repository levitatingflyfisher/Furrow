import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Furrow began as a copy of Sundial. Its outdoor-hours settings (annual
/// and monthly goal hours, the Flow timer face, auto-stop) were carried
/// along, stored and round-tripped, and read by nothing. This keeps them
/// from coming back.
void main() {
  test('no Sundial-only settings survive in lib/', () {
    final pattern = RegExp(
        r'annualGoalHours|monthlyGoalHours|FlowTimerStyle|flowTimerStyle|autoStop');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      if (pattern.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
