import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/features/notifications/domain/app_notification.dart';
import 'package:carelite_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:carelite_app/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:carelite_app/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:carelite_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:carelite_app/features/notifications/presentation/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsBloc
    extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

void main() {
  late _MockNotificationsBloc bloc;
  final now = DateTime.now();

  AppNotification build({
    required String id,
    required NotificationType type,
    required DateTime createdAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: 'Your Lipid Profile result is available',
      body: 'Tap to view it.',
      createdAt: createdAt,
      readAt: readAt,
    );
  }

  setUp(() => bloc = _MockNotificationsBloc());

  Future<void> pumpPage(WidgetTester tester, NotificationsState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsBloc>.value(
          value: bloc,
          child: const NotificationsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpPage(tester, const NotificationsState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty feed is still scrollable so it can be pulled to '
      'refresh', (tester) async {
    await pumpPage(
      tester,
      const NotificationsState(status: NotificationsStatus.ready),
    );

    // A Column-based empty state would make RefreshIndicator inert, leaving
    // the patient with no way to retry from an empty screen.
    expect(find.byType(NotificationCard), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('renders the notifications for the selected tab only',
      (tester) async {
    await pumpPage(
      tester,
      NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [
          build(
            id: '1',
            type: NotificationType.resultReady,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
          build(
            id: '2',
            type: NotificationType.incomingCall,
            createdAt: now.subtract(const Duration(days: 6)),
          ),
        ],
      ),
    );

    expect(find.byType(NotificationCard), findsOneWidget);
    expect(find.text('View result'), findsOneWidget);
  });

  testWidgets('offers Mark all read only when something is unread',
      (tester) async {
    await pumpPage(
      tester,
      NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [
          build(
            id: '1',
            type: NotificationType.resultReady,
            createdAt: now.subtract(const Duration(hours: 1)),
            readAt: now,
          ),
        ],
      ),
    );

    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets(
      'the whole card is tappable, so a notification with no destination can '
      'still be marked read', (tester) async {
    // PAYMENT and generic notifications get no action button (there is
    // nowhere to send the patient). When only the button was tappable, those
    // two types could never be marked read at all — they would sit unread
    // forever, holding the Home bell's badge on with nothing the patient
    // could do about it. A payment card is used here precisely because it
    // has no button and no navigation.
    await pumpPage(
      tester,
      NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [
          build(
            id: '1',
            type: NotificationType.payment,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
    );

    await tester.tap(find.byType(NotificationCard));
    await tester.pump();

    verify(() => bloc.add(const NotificationRead('1'))).called(1);
  });

  testWidgets('a payment notification offers no action button', (tester) async {
    // Payments are deferred backend-side — a "Pay now" button would lead
    // nowhere, so the card deliberately has none.
    await pumpPage(
      tester,
      NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [
          build(
            id: '1',
            type: NotificationType.payment,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
    );

    expect(find.byType(NotificationCard), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Pay now'), findsNothing);
  });
}
