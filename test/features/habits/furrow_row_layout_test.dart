import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furrow/core/storage/app_database.dart';
import 'package:furrow/features/habits/presentation/furrow_row.dart';

// The redesign's first law: logging is a thumb-sized moment. Every day cell
// must be a real touch target (>=40dp wide, >=44dp tall) at a 320dp phone —
// the old row packed 26px cells beside the name, and a near-miss navigated
// away instead of logging.
void main() {
  Habit habit({String cadence = 'binary'}) => Habit(
        id: 'h1',
        name: 'Morning pages',
        cadence: cadence,
        scheduleType: 'daily',
        targetValue: 1,
        weekdayMask: 127,
        colorValue: 0xFFB07A2E,
        archived: false,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
      );

  final monday = DateTime(2026, 7, 20);
  final week = [for (var i = 0; i < 7; i++) DateTime(2026, 7, 20 + i)];
  final today = DateTime(2026, 7, 24);

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(320, 640)),
            child: SizedBox(width: 320, child: child),
          ),
        ),
      );

  testWidgets('every day cell is a thumb target at 320dp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(FurrowRow(
      habit: habit(),
      weekDays: week,
      marks: const [],
      today: today,
      onTapDay: (_) {},
      onLongPressDay: (_) {},
    )));

    final cells = find.byKey(const ValueKey('today_h1'));
    expect(cells, findsOneWidget);
    final size = tester.getSize(cells);
    expect(size.width, greaterThanOrEqualTo(38),
        reason: 'seven thumb-width columns must fit a 320dp phone '
            '(${size.width} found)');
    expect(size.height, greaterThanOrEqualTo(44),
        reason: 'a cell shorter than 44dp is a fingernail target');
    expect(monday.weekday, DateTime.monday);
  });

  testWidgets('tapping a cell logs; only the name row navigates',
      (tester) async {
    DateTime? tapped;
    var opened = false;

    await tester.pumpWidget(host(FurrowRow(
      habit: habit(),
      weekDays: week,
      marks: const [],
      today: today,
      onTapDay: (d) => tapped = d,
      onLongPressDay: (_) {},
      onOpen: () => opened = true,
    )));

    await tester.tap(find.byKey(const ValueKey('today_h1')));
    expect(tapped, isNotNull, reason: 'a cell tap is a log, never navigation');
    expect(opened, isFalse);

    await tester.tap(find.text('Morning pages'));
    expect(opened, isTrue, reason: 'the name is the way into the habit');
  });
}
