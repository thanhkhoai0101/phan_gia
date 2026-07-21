import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'draw_room_state_event.dart';
import '../../services/draw_guess/draw_guess_service.dart';
import '../../models/draw_guess/draw_message_model.dart';
import '../../models/draw_guess/draw_room_model.dart';

const List<String> _kWordPool = [
  'Con mèo', 'Con chó', 'Quả táo', 'Xe đạp', 'Máy bay', 'Điện thoại',
  'Ngôi nhà', 'Cây bút', 'Cái bàn', 'Đôi giày', 'Máy tính', 'Bóng đá',
  'Cái ghế', 'Tivi', 'Bông hoa', 'Mặt trời', 'Mặt trăng', 'Ngôi sao',
  'Trái tim', 'Cái ly', 'Con cá', 'Con ếch', 'Con heo', 'Quả chuối'
];

class DrawRoomBloc extends Bloc<DrawRoomEvent, DrawRoomState> {
  final DrawGuessService _service;
  final String currentUserUid;
  final String currentUserName;

  StreamSubscription? _roomSub;
  StreamSubscription? _msgSub;
  String? _roomId;
  Timer? _turnTimer;

  DrawRoomBloc(this._service, this.currentUserUid, this.currentUserName) : super(DrawRoomLoading()) {
    on<JoinDrawRoomEvent>(_onJoinRoom);
    on<RoomUpdatedEvent>(_onRoomUpdated);
    on<MessagesUpdatedEvent>(_onMessagesUpdated);
    on<StartGameEvent>(_onStartGame);
    on<WordSelectedEvent>(_onWordSelected);
    on<SubmitGuessEvent>(_onSubmitGuess);
  }

  Future<void> _onJoinRoom(JoinDrawRoomEvent event, Emitter<DrawRoomState> emit) async {
    _roomId = event.roomId;
    
    _roomSub?.cancel();
    _roomSub = _service.listenRoomState(_roomId!).listen((room) {
      if (room != null) add(RoomUpdatedEvent(room));
    });

    _msgSub?.cancel();
    _msgSub = _service.listenMessages(_roomId!).listen((messages) {
      add(MessagesUpdatedEvent(messages));
    });
  }

  void _onRoomUpdated(RoomUpdatedEvent event, Emitter<DrawRoomState> emit) {
    emit(DrawRoomLoaded(room: event.room, messages: state.messages));
    _checkGameLogic(event.room);
  }

  void _onMessagesUpdated(MessagesUpdatedEvent event, Emitter<DrawRoomState> emit) {
    emit(DrawRoomLoaded(room: state.room, messages: event.messages));
  }

  void _checkGameLogic(DrawRoomModel room) {
    if (room.status == 'choosing_word' && room.hostId == currentUserUid && room.wordChoices.isEmpty) {
      // Host generates words for the drawer
      final random = Random();
      List<String> choices = [];
      while (choices.length < 3) {
        String word = _kWordPool[random.nextInt(_kWordPool.length)];
        if (!choices.contains(word)) choices.add(word);
      }
      _service.updateRoom(room.id, {'wordChoices': choices});
    }

    // Check if time is up for drawing
    if (room.status == 'drawing' && room.hostId == currentUserUid) {
      if (room.roundEndTime != null && DateTime.now().isAfter(room.roundEndTime!)) {
        _endRound(room);
      } else if (_turnTimer == null || !_turnTimer!.isActive) {
        _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (state.room?.status == 'drawing') {
            if (state.room!.roundEndTime != null && DateTime.now().isAfter(state.room!.roundEndTime!)) {
              timer.cancel();
              _endRound(state.room!);
            }
          } else {
            timer.cancel();
          }
        });
      }
    }
  }

  void _endRound(DrawRoomModel room) {
    _service.updateRoom(room.id, {
      'status': 'round_end',
    });
    
    // Add system message
    _service.sendMessage(room.id, DrawMessageModel(
      id: '',
      senderId: 'system',
      senderName: 'Hệ thống',
      text: 'Hết giờ! Đáp án là: ${room.secretWord}',
      timestamp: DateTime.now(),
      isSystemMsg: true,
    ));

    // Next round after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_roomId == null) return;
      int nextRound = room.currentRound;
      
      // Find next drawer
      int currentIndex = room.players.indexWhere((p) => p.uid == room.currentDrawerId);
      int nextIndex = currentIndex + 1;
      
      if (nextIndex >= room.players.length) {
        nextIndex = 0;
        nextRound++;
      }

      if (nextRound > room.totalRounds) {
        _service.updateRoomStatus(room.id, 'game_over');
      } else {
        String nextDrawer = room.players[nextIndex].uid;
        _service.updateRoom(room.id, {
          'status': 'choosing_word',
          'currentRound': nextRound,
          'currentDrawerId': nextDrawer,
          'wordChoices': [],
          'secretWord': '',
          // Reset players hasGuessed status
          'players': room.players.map((p) => p.copyWith(hasGuessed: false).toMap()).toList(),
        });
        _service.clearCanvas(room.id);
      }
    });
  }

  void _onStartGame(StartGameEvent event, Emitter<DrawRoomState> emit) {
    final room = state.room;
    if (room != null && room.hostId == currentUserUid) {
      _service.updateRoom(room.id, {
        'status': 'choosing_word',
        'currentRound': 1,
        'currentDrawerId': room.players.first.uid,
        'wordChoices': [],
        'secretWord': '',
      });
      _service.clearCanvas(room.id);
    }
  }

  void _onWordSelected(WordSelectedEvent event, Emitter<DrawRoomState> emit) {
    final room = state.room;
    if (room != null && room.currentDrawerId == currentUserUid) {
      _service.updateRoom(room.id, {
        'status': 'drawing',
        'secretWord': event.word,
        'roundEndTime': FieldValue.serverTimestamp(), // Will add seconds locally
      });
      // We set time manually so clients see exact time
      final endTime = DateTime.now().add(const Duration(seconds: 80));
      _service.updateRoom(room.id, {
        'roundEndTime': endTime,
      });
    }
  }

  void _onSubmitGuess(SubmitGuessEvent event, Emitter<DrawRoomState> emit) {
    final room = state.room;
    if (room == null || _roomId == null) return;

    String text = event.text.trim();
    bool isCorrect = false;

    if (room.status == 'drawing' && room.currentDrawerId != currentUserUid) {
      if (text.toLowerCase() == room.secretWord.toLowerCase()) {
        isCorrect = true;
        
        // Find player and update score
        final players = List<DrawPlayerModel>.from(room.players);
        final playerIdx = players.indexWhere((p) => p.uid == currentUserUid);
        if (playerIdx != -1 && !players[playerIdx].hasGuessed) {
          // Calculate score based on time left
          int scoreEarned = 10;
          if (room.roundEndTime != null) {
            final timeLeft = room.roundEndTime!.difference(DateTime.now()).inSeconds;
            if (timeLeft > 0) scoreEarned += (timeLeft ~/ 2);
          }
          
          players[playerIdx] = players[playerIdx].copyWith(
            score: players[playerIdx].score + scoreEarned,
            hasGuessed: true,
          );

          // Update drawer score as well
          final drawerIdx = players.indexWhere((p) => p.uid == room.currentDrawerId);
          if (drawerIdx != -1) {
             players[drawerIdx] = players[drawerIdx].copyWith(
               score: players[drawerIdx].score + 5,
             );
          }

          _service.updateRoom(room.id, {'players': players.map((p) => p.toMap()).toList()});
        }
      }
    }

    _service.sendMessage(_roomId!, DrawMessageModel(
      id: '',
      senderId: currentUserUid,
      senderName: currentUserName,
      text: isCorrect ? 'Đã đoán đúng từ khóa!' : text,
      timestamp: DateTime.now(),
      isCorrectGuess: isCorrect,
    ));
    
    // If all guessers guessed correctly, end round early
    if (isCorrect && room.hostId == currentUserUid) {
      bool allGuessed = true;
      for (var p in room.players) {
        if (p.uid != room.currentDrawerId && !p.hasGuessed) {
          allGuessed = false;
          break;
        }
      }
      if (allGuessed) {
        _endRound(room);
      }
    }
  }

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _msgSub?.cancel();
    _turnTimer?.cancel();
    return super.close();
  }
}
