part of 'caro_local_bloc.dart';

enum CaroLocalStatus {
  playing,
  finished,
}

class CaroLocalState {
  final CaroLocalStatus status;
  final List<List<int>> board;
  final int turn; // 1 for human (Black), 2 for bot (White)
  final int winner; // 0 for none, 1 for human, 2 for bot
  final int difficulty; // 1: Siêu dễ, 2: Dễ, 3: Bình thường, 4: Khó, 5: Siêu khó

  const CaroLocalState({
    this.status = CaroLocalStatus.playing,
    this.board = const [],
    this.turn = 1,
    this.winner = 0,
    this.difficulty = 3,
  });

  CaroLocalState copyWith({
    CaroLocalStatus? status,
    List<List<int>>? board,
    int? turn,
    int? winner,
    int? difficulty,
  }) {
    return CaroLocalState(
      status: status ?? this.status,
      board: board ?? this.board,
      turn: turn ?? this.turn,
      winner: winner ?? this.winner,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
