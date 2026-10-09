import 'package:equatable/equatable.dart';

sealed class PrecallEvent extends Equatable {
  const PrecallEvent();

  @override
  List<Object?> get props => [];
}

final class PrecallStarted extends PrecallEvent {
  const PrecallStarted();
}

final class PrecallItemToggled extends PrecallEvent {
  const PrecallItemToggled(this.item);

  final PrecallItem item;

  @override
  List<Object?> get props => [item];
}

final class PrecallSubmitted extends PrecallEvent {
  const PrecallSubmitted();
}

enum PrecallItem { quietLocation, cameraMicOk, connectionOk, documentsReady }
