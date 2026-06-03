part of 'caro_bloc.dart';

enum CaroStatus {
  initial,
  loading,
  waiting,
  playing,
  finished,
  error,
}

class CaroState {
  final CaroStatus status;
  final CaroModel? room;
  final String? message;

  const CaroState({
    this.status = CaroStatus.initial,
    this.room,
    this.message,
  });

  CaroState copyWith({
    CaroStatus? status,
    CaroModel? room,
    String? message,
  }) {
    return CaroState(
      status: status ?? this.status,
      room: room ?? this.room,
      message: message,
    );
  }
}
