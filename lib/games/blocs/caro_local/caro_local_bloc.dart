import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/caro_bot_logic.dart';
import '../../logic/caro_helper.dart';

part 'caro_local_event.dart';
part 'caro_local_state.dart';

class CaroLocalBloc extends Bloc<CaroLocalEvent, CaroLocalState> {
  CaroLocalBloc({int difficulty = 3}) : super(_initialState(difficulty)) {
    on<UserPlacePieceEvent>(_onUserPlacePiece);
    on<BotPlacePieceEvent>(_onBotPlacePiece);
    on<ResetLocalGameEvent>(_onResetLocalGame);
  }

  static CaroLocalState _initialState(int difficulty) {
    List<List<int>> board = List.generate(
      15,
      (_) => List.filled(15, 0),
    );
    return CaroLocalState(board: board, difficulty: difficulty);
  }

  void _onUserPlacePiece(
    UserPlacePieceEvent event,
    Emitter<CaroLocalState> emit,
  ) {
    if (state.status == CaroLocalStatus.finished) return;
    if (state.turn != CaroBotLogic.humanPlayer) return;
    if (state.board[event.row][event.col] != 0) return;

    List<List<int>> board = state.board.map((e) => List<int>.from(e)).toList();
    board[event.row][event.col] = CaroBotLogic.humanPlayer;

    bool isWin = CaroHelper.checkWin(
      board,
      event.row,
      event.col,
      CaroBotLogic.humanPlayer,
    );

    if (isWin) {
      emit(state.copyWith(
        board: board,
        status: CaroLocalStatus.finished,
        winner: CaroBotLogic.humanPlayer,
      ));
    } else {
      emit(state.copyWith(
        board: board,
        turn: CaroBotLogic.botPlayer,
      ));
      add(BotPlacePieceEvent()); // Kích hoạt Bot đi
    }
  }

  void _onBotPlacePiece(
    BotPlacePieceEvent event,
    Emitter<CaroLocalState> emit,
  ) async {
    if (state.status == CaroLocalStatus.finished) return;
    if (state.turn != CaroBotLogic.botPlayer) return;

    // Tùy theo độ khó mà giả lập thời gian suy nghĩ lâu hơn
    int delayMs = 500;
    if (state.difficulty >= 4) delayMs = 800; // Khó sẽ tốn chút thời gian
    await Future.delayed(Duration(milliseconds: delayMs));

    final bestMove = CaroBotLogic.findBestMove(state.board, state.difficulty);
    if (bestMove[0] == -1) return; // Bàn cờ đầy

    List<List<int>> board = state.board.map((e) => List<int>.from(e)).toList();
    board[bestMove[0]][bestMove[1]] = CaroBotLogic.botPlayer;

    bool isWin = CaroHelper.checkWin(
      board,
      bestMove[0],
      bestMove[1],
      CaroBotLogic.botPlayer,
    );

    if (isWin) {
      emit(state.copyWith(
        board: board,
        status: CaroLocalStatus.finished,
        winner: CaroBotLogic.botPlayer,
      ));
    } else {
      emit(state.copyWith(
        board: board,
        turn: CaroBotLogic.humanPlayer,
      ));
    }
  }

  void _onResetLocalGame(
    ResetLocalGameEvent event,
    Emitter<CaroLocalState> emit,
  ) {
    emit(_initialState(state.difficulty));
  }
}
