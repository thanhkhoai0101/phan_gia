import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:phan_family/games/models/caro_model.dart';
import 'package:phan_family/games/services/caro_service.dart';

import '../../logic/caro_helper.dart';

part 'caro_event.dart';
part 'caro_state.dart';

class CaroBloc
    extends Bloc<CaroEvent, CaroState> {
  final CaroService repository;

  StreamSubscription? roomSub;

  CaroBloc(this.repository)
      : super(const CaroState()) {
    on<CreateRoomEvent>(_createRoom);
    on<JoinRoomEvent>(_joinRoom);
    on<ListenRoomEvent>(_listenRoom);
    on<RoomUpdatedEvent>(_roomUpdated);
    on<PlacePieceEvent>(_placePiece);
    on<ResetCaroEvent>(_resetGame);
  }

  Future<void> _createRoom(
      CreateRoomEvent event,
      Emitter<CaroState> emit,
      ) async {
    emit(
      state.copyWith(
        status: CaroStatus.loading,
      ),
    );

    String roomId =
    DateTime.now()
        .millisecondsSinceEpoch
        .toString();

    List<List<int>> board =
    List.generate(
      15,
          (_) => List.filled(15, 0),
    );

    await repository.roomRef
        .doc(roomId)
        .set({
      "roomId": roomId,
      "hostId": event.uid,
      "guestId": "",
      "hostName": event.name,
      "guestName": "",
      "turn": 1,
      "winner": 0,
      "status": "waiting",
      "board": CaroModel.boardToFlat(board), // flat 1D
      "createdAt":
      FieldValue.serverTimestamp(),
    });

    add(
      ListenRoomEvent(roomId),
    );
  }

  Future<void> _joinRoom(
      JoinRoomEvent event,
      Emitter<CaroState> emit,
      ) async {
    await repository.roomRef
        .doc(event.roomId)
        .update({
      "guestId": event.uid,
      "guestName": event.name,
      "status": "playing",
    });

    add(
      ListenRoomEvent(
        event.roomId,
      ),
    );
  }

  Future<void> _listenRoom(
      ListenRoomEvent event,
      Emitter<CaroState> emit,
      ) async {
    await roomSub?.cancel();

    roomSub =
        repository.roomStream(
          event.roomId,
        ).listen(
              (room) {
            add(
              RoomUpdatedEvent(
                room,
              ),
            );
          },
        );
  }

  void _roomUpdated(
      RoomUpdatedEvent event,
      Emitter<CaroState> emit,
      ) {
    CaroStatus newStatus;
    if (event.room.winner != 0) {
      newStatus = CaroStatus.finished;
    } else if (event.room.status == "waiting") {
      newStatus = CaroStatus.waiting;
    } else {
      newStatus = CaroStatus.playing;
    }

    emit(
      state.copyWith(
        room: event.room,
        status: newStatus,
      ),
    );
  }

  Future<void> _placePiece(
      PlacePieceEvent event,
      Emitter<CaroState> emit,
      ) async {
    final room = state.room;

    if (room == null) return;

    bool isHost =
        room.hostId == event.uid;

    int player =
    isHost ? 1 : 2;

    if (room.turn != player) {
      return;
    }

    if (room.board[event.row]
    [event.col] !=
        0) {
      return;
    }

    List<List<int>> board =
    room.board
        .map(
          (e) => List<int>.from(e),
    )
        .toList();

    board[event.row][event.col] =
        player;

    bool isWin =
    CaroHelper.checkWin(
      board,
      event.row,
      event.col,
      player,
    );

    await repository.roomRef
        .doc(room.roomId)
        .update({
      "board": CaroModel.boardToFlat(board), // flat 1D
      "turn":
      player == 1 ? 2 : 1,
      "winner":
      isWin ? player : 0,
    });
  }

  Future<void> _resetGame(
      ResetCaroEvent event,
      Emitter<CaroState> emit,
      ) async {
    final room = state.room;

    if (room == null) return;

    List<List<int>> board =
    List.generate(
      15,
          (_) => List.filled(15, 0),
    );

    await repository.roomRef
        .doc(room.roomId)
        .update({
      "board": CaroModel.boardToFlat(board), // flat 1D
      "winner": 0,
      "turn": 1,
      "status": "playing",
    });
  }

  @override
  Future<void> close() {
    roomSub?.cancel();
    return super.close();
  }
}
