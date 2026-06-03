import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/bau_cua_model.dart';
import '../../services/bau_cua_service.dart';
import 'bau_cua_event.dart';
import 'bau_cua_state.dart';

class BauCuaBloc extends Bloc<BauCuaEvent, BauCuaState> {
  final BauCuaService _service;
  StreamSubscription? _roomSub;
  Timer? _gameTimer;

  BauCuaBloc({required BauCuaService service}) : _service = service, super(const BauCuaState()) {
    on<LoadRoom>(_onLoadRoom);
    on<UpdateRoomData>(_onUpdateRoomData);
    on<PlaceBetEvent>(_onPlaceBet);
    on<StartRound>(_onStartRound);
  }

  void _onLoadRoom(LoadRoom event, Emitter<BauCuaState> emit) {
    emit(state.copyWith(isLoading: true));
    _roomSub?.cancel();
    _roomSub = _service.streamRoom(event.roomId).listen((room) {
      add(UpdateRoomData(room));
    });
  }

  void _onUpdateRoomData(UpdateRoomData event, Emitter<BauCuaState> emit) {
    emit(state.copyWith(room: event.room, isLoading: false));
    
    // Auto-advance state if we are host
    if (event.room.hostUid == _service.currentUser?.uid) {
      _handleHostLogic(event.room);
    }
  }

  void _handleHostLogic(BauCuaRoom room) {
    if (room.status == 'betting' && room.timerSeconds > 0) {
      if (_gameTimer == null || !_gameTimer!.isActive) {
        _startTimer(room.id, room.timerSeconds);
      }
    } else if (room.status == 'betting' && room.timerSeconds == 0) {
      _rollDice(room.id);
    } else if (room.status == 'result' && room.timerSeconds == 0) {
      // Ready for next round
      _service.updateRoomStatus(room.id, 'waiting');
    }
  }

  void _startTimer(String roomId, int initialSeconds) {
    _gameTimer?.cancel();
    int current = initialSeconds;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      current--;
      if (current < 0) {
        timer.cancel();
      } else {
        _service.updateRoomStatus(roomId, 'betting', timer: current);
      }
    });
  }

  Future<void> _rollDice(String roomId) async {
    _gameTimer?.cancel();
    await _service.updateRoomStatus(roomId, 'rolling');
    
    // Simulate roll animation for 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    
    final random = Random();
    List<int> results = [
      random.nextInt(6),
      random.nextInt(6),
      random.nextInt(6),
    ];
    
    await _service.settleBets(roomId, results);
  }

  Future<void> _onPlaceBet(PlaceBetEvent event, Emitter<BauCuaState> emit) async {
    if (state.room == null || state.room!.status != 'betting') return;
    
    try {
      await _service.placeBet(state.room!.id, event.mascotIndex, event.amount, event.userName);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onStartRound(StartRound event, Emitter<BauCuaState> emit) {
    if (state.room == null) return;
    _service.updateRoomStatus(state.room!.id, 'betting', timer: 30);
  }

  @override
  Future<void> close() {
    _roomSub?.cancel();
    _gameTimer?.cancel();
    return super.close();
  }
}
