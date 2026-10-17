import 'package:carelite_app/features/find_clinician/presentation/widgets/slot_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  final day1 = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  final day2 = day1.add(const Duration(days: 1));
  final morning = day1.add(const Duration(hours: 9));
  final afternoon = day1.add(const Duration(hours: 14));
  final laterDay = day2.add(const Duration(hours: 10, minutes: 20));

  Future<List<DateTime>> pump(WidgetTester tester, {DateTime? selected}) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotPicker(
            slotsByDay: {
              day1: [afternoon, morning],
              day2: [laterDay],
            },
            selected: selected,
            onSelected: picked.add,
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('shows only the first day\'s times, grouped by part of day',
      (tester) async {
    await pump(tester);

    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('2:00 PM'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('10:20 AM'), findsNothing);
  });

  testWidgets('tapping another day shows that day\'s times', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('1 time available')));
    await tester.pump();

    expect(find.text('10:20 AM'), findsOneWidget);
    expect(find.text('9:00 AM'), findsNothing);
  });

  testWidgets('opens on the day of an already chosen time', (tester) async {
    await pump(tester, selected: laterDay);

    expect(find.text('10:20 AM'), findsOneWidget);
  });

  testWidgets('tapping a time reports it', (tester) async {
    final picked = await pump(tester);

    await tester.tap(find.text('2:00 PM'));

    expect(picked, [afternoon]);
  });
}
