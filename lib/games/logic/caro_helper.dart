class CaroHelper {
  static bool checkWin(
      List<List<int>> board,
      int row,
      int col,
      int player,
      ) {
    List<List<int>> directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (var dir in directions) {
      int count = 1;

      count += _count(
        board,
        row,
        col,
        dir[0],
        dir[1],
        player,
      );

      count += _count(
        board,
        row,
        col,
        -dir[0],
        -dir[1],
        player,
      );

      if (count >= 5) {
        return true;
      }
    }

    return false;
  }

  static int _count(
      List<List<int>> board,
      int row,
      int col,
      int dx,
      int dy,
      int player,
      ) {
    int count = 0;

    int r = row + dx;
    int c = col + dy;

    while (
    r >= 0 &&
        c >= 0 &&
        r < board.length &&
        c < board.length &&
        board[r][c] == player) {
      count++;
      r += dx;
      c += dy;
    }

    return count;
  }
}
