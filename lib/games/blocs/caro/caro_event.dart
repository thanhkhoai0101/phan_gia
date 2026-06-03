part of 'caro_bloc.dart';

@immutable
sealed class CaroEvent {}

class CreateRoomEvent extends CaroEvent {
  final String uid;
  final String name;

  CreateRoomEvent({
    required this.uid,
    required this.name,
  });
}

class JoinRoomEvent extends CaroEvent {
  final String roomId;
  final String uid;
  final String name;

  JoinRoomEvent({
    required this.roomId,
    required this.uid,
    required this.name,
  });
}

class ListenRoomEvent extends CaroEvent {
  final String roomId;

  ListenRoomEvent(this.roomId);
}

class RoomUpdatedEvent extends CaroEvent {
  final CaroModel room;

  RoomUpdatedEvent(this.room);
}

class PlacePieceEvent extends CaroEvent {
  final int row;
  final int col;
  final String uid;

  PlacePieceEvent({
    required this.row,
    required this.col,
    required this.uid,
  });
}

class ResetCaroEvent extends CaroEvent {}
