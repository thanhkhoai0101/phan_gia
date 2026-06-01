import 'package:equatable/equatable.dart';

import '../../models/card_model.dart';
import '../../models/room_model.dart';

abstract class TienLenRoomEvent extends Equatable {
  const TienLenRoomEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToRoom extends TienLenRoomEvent {
  final String roomId;
  const SubscribeToRoom(this.roomId);
}

class RoomUpdated extends TienLenRoomEvent {
  final RoomModel? room;
  final String currentUserId;
  const RoomUpdated(this.room, this.currentUserId);
}

class ToggleCardSelection extends TienLenRoomEvent {
  final CardModel card;
  const ToggleCardSelection(this.card);
}

class ClearSelection extends TienLenRoomEvent {
  const ClearSelection();
}

class TimerTick extends TienLenRoomEvent {
  const TimerTick();
}

class PlayCardsAction extends TienLenRoomEvent {
  final String roomId;
  final String userId;
  const PlayCardsAction(this.roomId, this.userId);
}

class PassTurnAction extends TienLenRoomEvent {
  final String roomId;
  final String userId;
  const PassTurnAction(this.roomId, this.userId);
}

class ShowEffectEvent extends TienLenRoomEvent {
  final String text;
  final dynamic color;
  const ShowEffectEvent(this.text, this.color);
}

class SoundPlayed extends TienLenRoomEvent {
  const SoundPlayed();
}
