import 'dart:math';

class CaroBotLogic {
  static const int boardSize = 15;
  static const int botPlayer = 2; // Bot is player 2 (White)
  static const int humanPlayer = 1; // Human is player 1 (Black)

  static List<int> findBestMove(List<List<int>> board, int difficulty) {
    bool hasAnyPiece = false;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] != 0) {
          hasAnyPiece = true;
          break;
        }
      }
    }
    
    // Nước đầu tiên nếu bàn trống luôn đánh giữa bàn
    if (!hasAnyPiece) return [7, 7];

    switch (difficulty) {
      case 1:
        return _getHeuristicMove(board); // Siêu dễ: Pattern matching
      case 2:
        return _getMinimaxMove(board, 2); // Dễ: Minimax Depth 2
      case 3:
        return _getMinimaxMove(board, 3); // Bình thường: Minimax Depth 3
      case 4:
        return _getMinimaxMove(board, 4); // Khó: Minimax Depth 4
      case 5:
        return _getMinimaxMove(board, 5); // Siêu khó: Minimax Depth 5
      default:
        return _getHeuristicMove(board);
    }
  }

  static List<int> _getHeuristicMove(List<List<int>> board) {
     var moves = _generateMoves(board, botPlayer);
     if (moves.isEmpty) return [7, 7];
     return [moves[0].row, moves[0].col];
  }

  static List<int> _getMinimaxMove(List<List<int>> board, int depth) {
    var moves = _generateMoves(board, botPlayer);
    if (moves.isEmpty) return [7, 7];
    if (moves.length == 1) return [moves[0].row, moves[0].col];
    
    // Nếu có nước đi thắng luôn hoặc cần chặn ngay lập tức, ưu tiên đánh luôn 
    // Tránh việc duyệt minimax sâu làm trễ
    if (moves[0].score >= 1000000) {
      return [moves[0].row, moves[0].col];
    }
    
    int bestScore = -999999999;
    List<int> bestMove = [moves[0].row, moves[0].col];
    
    int alpha = -999999999;
    int beta = 999999999;
    
    // Lọc ra top N nước cờ tiềm năng nhất để duyệt
    int limit = depth >= 3 ? 12 : 20; 
    var topMoves = moves.take(limit).toList();

    for (var move in topMoves) {
      board[move.row][move.col] = botPlayer;
      int score = _minimax(board, depth - 1, alpha, beta, false);
      board[move.row][move.col] = 0; // Backtrack
      
      if (score > bestScore) {
        bestScore = score;
        bestMove = [move.row, move.col];
      }
      alpha = max(alpha, bestScore);
    }
    
    return bestMove;
  }

  static int _minimax(List<List<int>> board, int depth, int alpha, int beta, bool isMaximizing) {
     if (depth == 0) {
        return _evaluateBoard(board);
     }
     
     int player = isMaximizing ? botPlayer : humanPlayer;
     var moves = _generateMoves(board, player);
     
     if (moves.isEmpty) return 0;
     
     // Phát hiện nhánh kết thúc sớm (có thế cờ thắng)
     if (moves[0].score >= 20000000) { 
        return isMaximizing ? 20000000 + depth : -20000000 - depth;
     }
     
     int limit = depth >= 2 ? 8 : 12;
     var topMoves = moves.take(limit).toList();
     
     if (isMaximizing) {
       int maxEval = -999999999;
       for (var move in topMoves) {
         board[move.row][move.col] = botPlayer;
         int eval = _minimax(board, depth - 1, alpha, beta, false);
         board[move.row][move.col] = 0;
         maxEval = max(maxEval, eval);
         alpha = max(alpha, eval);
         if (beta <= alpha) break; // Cắt tỉa Alpha-Beta
       }
       return maxEval;
     } else {
       int minEval = 999999999;
       for (var move in topMoves) {
         board[move.row][move.col] = humanPlayer;
         int eval = _minimax(board, depth - 1, alpha, beta, true);
         board[move.row][move.col] = 0;
         minEval = min(minEval, eval);
         beta = min(beta, eval);
         if (beta <= alpha) break; // Cắt tỉa Alpha-Beta
       }
       return minEval;
     }
  }

  static int _evaluateBoard(List<List<int>> board) {
    int totalScore = 0;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == 0 && _hasNeighbor(board, r, c, 1)) {
           int botScore = _evaluatePoint(board, r, c, botPlayer);
           int humanScore = _evaluatePoint(board, r, c, humanPlayer);
           totalScore += botScore - humanScore;
        }
      }
    }
    return totalScore;
  }
  
  static List<_Move> _generateMoves(List<List<int>> board, int player) {
    List<_Move> moves = [];
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == 0 && _hasNeighbor(board, r, c, 2)) {
          int attackScore = _evaluatePoint(board, r, c, botPlayer);
          int defenseScore = _evaluatePoint(board, r, c, humanPlayer);
          
          int totalScore = attackScore + defenseScore;
          if (defenseScore >= 1000000) totalScore += defenseScore; 
          if (attackScore >= 1000000) totalScore += attackScore * 2;
          
          moves.add(_Move(r, c, totalScore));
        }
      }
    }
    // Sắp xếp các nước cờ tiềm năng nhất lên đầu để Alpha-Beta cắt tỉa hiệu quả hơn
    moves.sort((a, b) => b.score.compareTo(a.score));
    return moves;
  }

  static bool _hasNeighbor(List<List<int>> board, int row, int col, int radius) {
    for (int i = -radius; i <= radius; i++) {
      for (int j = -radius; j <= radius; j++) {
        if (i == 0 && j == 0) continue;
        int r = row + i;
        int c = col + j;
        if (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
          if (board[r][c] != 0) return true;
        }
      }
    }
    return false;
  }

  static int _evaluatePoint(List<List<int>> board, int row, int col, int player) {
    int score = 0;
    int opponent = player == botPlayer ? humanPlayer : botPlayer;

    final directions = [
      [0, 1], // Ngang
      [1, 0], // Dọc
      [1, 1], // Chéo chính
      [1, -1], // Chéo phụ
    ];

    for (var dir in directions) {
      String pattern = "";
      
      for (int i = -4; i <= 4; i++) {
        if (i == 0) {
          pattern += "1";
          continue;
        }
        
        int r = row + i * dir[0];
        int c = col + i * dir[1];
        
        if (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
          if (board[r][c] == player) {
            pattern += "1";
          } else if (board[r][c] == opponent) {
            pattern += "2";
          } else {
            pattern += "0";
          }
        } else {
          pattern += "2";
        }
      }

      score += _scorePattern(pattern);
    }

    return score;
  }

  static int _scorePattern(String pattern) {
    if (pattern.contains("11111")) return 20000000;
    if (pattern.contains("011110")) return 5000000;
    if (pattern.contains("211110") || pattern.contains("011112")) return 1500000;
    if (pattern.contains("10111") || pattern.contains("11101") || pattern.contains("11011")) return 1500000;
    if (pattern.contains("011100") || pattern.contains("001110")) return 500000;
    if (pattern.contains("010110") || pattern.contains("011010")) return 500000;
    if (pattern.contains("211100") || pattern.contains("001112")) return 50000;
    if (pattern.contains("210110") || pattern.contains("011012")) return 50000;
    if (pattern.contains("211010") || pattern.contains("010112")) return 50000;
    if (pattern.contains("10011") || pattern.contains("11001")) return 50000;
    if (pattern.contains("10101")) return 50000;
    if (pattern.contains("001100") || pattern.contains("011000") || pattern.contains("000110")) return 5000;
    if (pattern.contains("010100") || pattern.contains("001010")) return 5000;
    if (pattern.contains("010010")) return 5000;
    if (pattern.contains("211000") || pattern.contains("000112")) return 500;
    if (pattern.contains("210100") || pattern.contains("001012")) return 500;
    if (pattern.contains("210010") || pattern.contains("010012")) return 500;
    if (pattern.contains("00100")) return 50;
    
    return 0;
  }
}

class _Move {
  final int row;
  final int col;
  final int score;
  _Move(this.row, this.col, this.score);
}
