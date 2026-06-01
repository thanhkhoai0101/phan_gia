import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../../logic/tien_len_logic.dart';
import '../../models/card_model.dart';
import '../../services/room_service.dart';
import 'tien_len_room_event.dart';
import 'tien_len_room_state.dart';

class TienLenRoomBloc extends Bloc<TienLenRoomEvent, TienLenRoomState> {
  final RoomService _roomService = RoomService();
  StreamSubscription? _roomSubscription;
  Timer? _turnTimer;
  String? _lastTurnId;
  int? _lastStartedAt;
  bool _hasPlayedEndSound = false;
  bool _hasJoined = false;

  TienLenRoomBloc() : super(const TienLenRoomState()) {
    on<SubscribeToRoom>(_onSubscribeToRoom);
    on<RoomUpdated>(_onRoomUpdated);
    on<ToggleCardSelection>(_onToggleCardSelection);
    on<ClearSelection>(_onClearSelection);
    on<TimerTick>(_onTimerTick);
    on<PlayCardsAction>(_onPlayCards);
    on<PassTurnAction>(_onPassTurn);
    on<ShowEffectEvent>(_onShowEffect);
    on<SoundPlayed>(_onSoundPlayed);
  }

  void _onSubscribeToRoom(SubscribeToRoom event, Emitter<TienLenRoomState> emit) {
    _roomSubscription?.cancel();
    _roomSubscription = _roomService.streamRoom(event.roomId).listen((room) {
      // In a real app, you'd get currentUserId from a more robust source
      // but we'll assume it's passed or handled when the first RoomUpdated is triggered
      // For now, we need a way to pass currentUserId to the Bloc.
      // We'll update the event to include it if needed.
    });
  }

  void _onRoomUpdated(RoomUpdated event, Emitter<TienLenRoomState> emit) {
    final room = event.room;
    if (room == null) {
      // Room was deleted
      emit(state.copyWith(isKicked: true));
      return;
    }

    // Check if player has joined successfully
    final bool currentlyInRoom = room.players.contains(event.currentUserId);
    if (currentlyInRoom) {
      _hasJoined = true;
    }

    // Check if kicked: must have been in room before, and now is not, and game is not finished
    // Chủ phòng (Host) thì KHÔNG bao giờ bị kích
    bool isKicked = _hasJoined && !currentlyInRoom && room.status != 'finished' && room.hostId != event.currentUserId;

    String? sound;
    String? effectText;
    Color? effectColor;

    if (room.status == 'playing' || room.status == 'finished') {
      if (room.status == 'playing') {
        final gameState = room.gameState!;
        final currentTurnId = gameState.currentTurnId;
        final startedAt = gameState.turnStartedAt;

        if (_lastTurnId != currentTurnId || _lastStartedAt != startedAt) {
          _lastTurnId = currentTurnId;
          _lastStartedAt = startedAt;
          
          if (currentTurnId == event.currentUserId) {
            sound = 'toi_luot_choi.mp3';
          }

          if (gameState.lastPlayedCards.isNotEmpty) {
            final result = TienLenLogic.analyzeHand(gameState.lastPlayedCards);
            if ((result.type == HandType.single || result.type == HandType.pair) && result.highestCard.rank == CardRank.two) {
              sound = 'heo_ne.mp3';
              effectText = 'HEO NÈ!!';
              effectColor = Colors.orangeAccent;
            } else if (result.type == HandType.fourOfAKind || result.type == HandType.fourDoubleSequence || result.type == HandType.threeDoubleSequence) {
              sound = 'chet_may_chua.mp3';
              effectText = 'CHẶT HEO!!';
              effectColor = Colors.redAccent;
            } else {
              sound = 'danh_bai.mp3';
            }
          }
          _startTimer();
          emit(state.copyWith(room: room, isKicked: isKicked, secondsLeft: 15, soundToPlay: sound, effectText: effectText, effectColor: effectColor));
          return;
        }
      } else if (room.status == 'finished') {
        _turnTimer?.cancel();
        if (!_hasPlayedEndSound) {
          _hasPlayedEndSound = true;
          if (room.gameState!.winners.contains(event.currentUserId)) {
            sound = 'victory.mp3';
            effectText = 'THẮNG RỒI!!';
            effectColor = Colors.greenAccent;
          } else {
            sound = 'over.mp3';
            effectText = 'THUA RỒI!!';
            effectColor = Colors.grey;
          }
        }
      } else {
        _hasPlayedEndSound = false;
      }
    } else {
      _turnTimer?.cancel();
    }

    emit(state.copyWith(room: room, isKicked: isKicked, soundToPlay: sound, effectText: effectText, effectColor: effectColor));
  }

  void _startTimer() {
    _turnTimer?.cancel();
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      add(const TimerTick());
    });
  }

  void _onTimerTick(TimerTick event, Emitter<TienLenRoomState> emit) {
    if (state.secondsLeft > 0) {
      int newSeconds = state.secondsLeft - 1;
      String? sound;
      if (newSeconds <= 5 && newSeconds > 0) {
        // We'll play countdown sound only if it's our turn
        // The UI listener will handle this by checking state.room.currentTurnId
        sound = '5second.mp3';
      }
      emit(state.copyWith(secondsLeft: newSeconds, soundToPlay: sound));
      if (newSeconds == 0) {
        _turnTimer?.cancel();
      }
    }
  }

  void _onToggleCardSelection(ToggleCardSelection event, Emitter<TienLenRoomState> emit) {
    final newSelection = Set<CardModel>.from(state.selectedCards);
    if (newSelection.contains(event.card)) {
      newSelection.remove(event.card);
    } else {
      newSelection.add(event.card);
    }
    emit(state.copyWith(selectedCards: newSelection));
  }

  void _onClearSelection(ClearSelection event, Emitter<TienLenRoomState> emit) {
    emit(state.copyWith(selectedCards: {}));
  }

  void _onPlayCards(PlayCardsAction event, Emitter<TienLenRoomState> emit) async {
    if (state.selectedCards.isEmpty) return;
    await _roomService.playCards(event.roomId, event.userId, state.selectedCards.toList());
    emit(state.copyWith(selectedCards: {}));
  }

  void _onPassTurn(PassTurnAction event, Emitter<TienLenRoomState> emit) async {
    await _roomService.passTurn(event.roomId, event.userId);
    emit(state.copyWith(selectedCards: {}));
  }

  void _onShowEffect(ShowEffectEvent event, Emitter<TienLenRoomState> emit) {
    emit(state.copyWith(effectText: event.text, effectColor: event.color));
  }

  void _onSoundPlayed(SoundPlayed event, Emitter<TienLenRoomState> emit) {
    emit(state.copyWith(soundToPlay: null));
  }

  @override
  Future<void> close() {
    _roomSubscription?.cancel();
    _turnTimer?.cancel();
    return super.close();
  }
}
