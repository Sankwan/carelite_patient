import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/notifications/data/notification_repository.dart';
import 'package:carelite_app/features/notifications/domain/app_notification.dart';
import 'package:carelite_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:carelite_app/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:carelite_app/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late _MockNotificationRepository repository;

  final now = DateTime.now();

  AppNotification build({
    required String id,
    required DateTime createdAt,
    DateTime? readAt,
    NotificationType type = NotificationType.clinicianAssigned,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: 'Dr. Adjei accepted your request',
      createdAt: createdAt,
      readAt: readAt,
    );
  }

  late AppNotification unreadToday;
  late AppNotification readToday;
  late AppNotification lastWeek;

  setUp(() {
    repository = _MockNotificationRepository();
    unreadToday = build(id: '1', createdAt: now.subtract(const Duration(hours: 1)));
    readToday = build(
      id: '2',
      createdAt: now.subtract(const Duration(hours: 3)),
      readAt: now.subtract(const Duration(hours: 2)),
    );
    lastWeek = build(id: '3', createdAt: now.subtract(const Duration(days: 7)));

    when(() => repository.markRead(any()))
        .thenAnswer((_) async => const Result.ok(null));
    when(() => repository.markAllRead())
        .thenAnswer((_) async => const Result.ok(null));
  });

  NotificationsBloc buildBloc() =>
      NotificationsBloc(notificationRepository: repository);

  void stubList(List<AppNotification> notifications) {
    when(() => repository.fetchAll(unreadOnly: any(named: 'unreadOnly')))
        .thenAnswer((_) async => Result.ok(notifications));
  }

  group('NotificationsBloc', () {
    blocTest<NotificationsBloc, NotificationsState>(
      'loads the list and counts what is unread',
      build: () {
        stubList([unreadToday, readToday, lastWeek]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const NotificationsStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, NotificationsStatus.ready);
        expect(bloc.state.notifications, hasLength(3));
        expect(bloc.state.unreadCount, 2);
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'the two tabs together account for every notification',
      build: () {
        stubList([unreadToday, readToday, lastWeek]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const NotificationsStarted()),
      skip: 1,
      verify: (bloc) {
        // Nothing may fall between Today and Past and become invisible.
        final today = bloc.state.visible();
        final past = bloc.state
            .copyWith(filter: NotificationsFilter.past)
            .visible();
        expect(today.map((n) => n.id), ['1', '2']);
        expect(past.map((n) => n.id), ['3']);
        expect(today.length + past.length, bloc.state.notifications.length);
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'filtering re-reads the page it already has, never the network again',
      build: () {
        stubList([unreadToday, lastWeek]);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const NotificationsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationsFilterChanged(NotificationsFilter.past));
      },
      verify: (bloc) {
        // The backend has no date filter, so a second round trip would
        // return exactly the same rows.
        verify(() => repository.fetchAll(unreadOnly: any(named: 'unreadOnly')))
            .called(1);
        expect(bloc.state.filter, NotificationsFilter.past);
        expect(bloc.state.visible().map((n) => n.id), ['3']);
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'marking read greys the row out before the server answers',
      build: () {
        stubList([unreadToday, lastWeek]);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const NotificationsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationRead('1'));
      },
      verify: (bloc) {
        expect(bloc.state.notifications.first.isUnread, isFalse);
        verify(() => repository.markRead('1')).called(1);
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'a rejected mark-read rolls the row back instead of lying to the '
      'patient',
      build: () {
        stubList([unreadToday, lastWeek]);
        when(() => repository.markRead('1'))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const NotificationsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationRead('1'));
      },
      verify: (bloc) {
        // Leaving it grey would hide a notification the server still
        // considers unread — it would vanish from the badge and never come
        // back on the next load.
        expect(bloc.state.notifications.first.isUnread, isTrue);
        expect(bloc.state.failure, isA<NetworkFailure>());
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'marking an already-read notification does not call the server',
      build: () {
        stubList([readToday]);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const NotificationsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationRead('2'));
      },
      verify: (_) => verifyNever(() => repository.markRead(any())),
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'mark-all-read clears every unread row, and rolls all of them back on '
      'failure',
      build: () {
        stubList([unreadToday, readToday, lastWeek]);
        when(() => repository.markAllRead())
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const NotificationsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationsAllRead());
      },
      verify: (bloc) {
        expect(bloc.state.unreadCount, 2);
        expect(bloc.state.failure, isA<NetworkFailure>());
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'a load failure shows an error over the list, not instead of it',
      build: () {
        when(() => repository.fetchAll(unreadOnly: any(named: 'unreadOnly')))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const NotificationsStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, NotificationsStatus.ready);
        expect(bloc.state.failure, isA<NetworkFailure>());
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'reaches ready with a failure even if the repository throws outright',
      build: () {
        // Same regression guard as HomeBloc: an uncaught throw must never
        // strand the screen on its spinner.
        when(() => repository.fetchAll(unreadOnly: any(named: 'unreadOnly')))
            .thenThrow(StateError('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const NotificationsStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, NotificationsStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );

    test('relativeLabel says the time today, Yesterday, then the date', () {
      final reference = DateTime(2026, 9, 8, 18);
      expect(
        build(id: 'x', createdAt: DateTime(2026, 9, 8, 14, 30))
            .relativeLabel(now: reference),
        '2:30 PM',
      );
      expect(
        build(id: 'x', createdAt: DateTime(2026, 9, 7, 9))
            .relativeLabel(now: reference),
        'Yesterday',
      );
      expect(
        build(id: 'x', createdAt: DateTime(2026, 9, 4, 9))
            .relativeLabel(now: reference),
        '4 Sep',
      );
    });
  });
}
