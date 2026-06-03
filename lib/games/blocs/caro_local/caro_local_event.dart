part of 'caro_local_bloc.dart';

sealed class CaroLocalEvent {}

class UserPlacePieceEvent extends CaroLocalEvent {
  final int row;
  final int col;

  UserPlacePieceEvent(this.row, this.col);
}

class BotPlacePieceEvent extends CaroLocalEvent {}

class ResetLocalGameEvent extends CaroLocalEvent {}
