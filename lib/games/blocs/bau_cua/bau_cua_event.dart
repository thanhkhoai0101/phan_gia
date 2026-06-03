import 'package:equatable/equatable.dart';

import '../../models/bau_cua_model.dart';

abstract class BauCuaEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadRoom extends BauCuaEvent {
  final String roomId;
  LoadRoom(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class UpdateRoomData extends BauCuaEvent {
  final BauCuaRoom room;
  UpdateRoomData(this.room);
  @override
  List<Object?> get props => [room];
}

class PlaceBetEvent extends BauCuaEvent {
  final int mascotIndex;
  final int amount;
  final String userName;
  PlaceBetEvent(this.mascotIndex, this.amount, this.userName);
  @override
  List<Object?> get props => [mascotIndex, amount, userName];
}

class StartRound extends BauCuaEvent {}
