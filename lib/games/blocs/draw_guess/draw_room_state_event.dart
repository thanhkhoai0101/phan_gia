import 'package:equatable/equatable.dart';
import '../../models/draw_guess/draw_room_model.dart';
import '../../models/draw_guess/draw_message_model.dart';

// --- EVENTS ---
abstract class DrawRoomEvent extends Equatable {
  const DrawRoomEvent();
  @override
  List<Object?> get props => [];
}

class JoinDrawRoomEvent extends DrawRoomEvent {
  final String roomId;
  const JoinDrawRoomEvent(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class RoomUpdatedEvent extends DrawRoomEvent {
  final DrawRoomModel room;
  const RoomUpdatedEvent(this.room);
  @override
  List<Object?> get props => [room];
}

class StartGameEvent extends DrawRoomEvent {}

class WordSelectedEvent extends DrawRoomEvent {
  final String word;
  const WordSelectedEvent(this.word);
  @override
  List<Object?> get props => [word];
}

class SubmitGuessEvent extends DrawRoomEvent {
  final String text;
  const SubmitGuessEvent(this.text);
  @override
  List<Object?> get props => [text];
}

class MessagesUpdatedEvent extends DrawRoomEvent {
  final List<DrawMessageModel> messages;
  const MessagesUpdatedEvent(this.messages);
  @override
  List<Object?> get props => [messages];
}

// --- STATES ---
abstract class DrawRoomState extends Equatable {
  final DrawRoomModel? room;
  final List<DrawMessageModel> messages;
  final String error;

  const DrawRoomState({this.room, this.messages = const [], this.error = ''});
  
  @override
  List<Object?> get props => [room, messages, error];
}

class DrawRoomLoading extends DrawRoomState {}

class DrawRoomLoaded extends DrawRoomState {
  const DrawRoomLoaded({super.room, super.messages});
}

class DrawRoomError extends DrawRoomState {
  const DrawRoomError(String error) : super(error: error);
}
