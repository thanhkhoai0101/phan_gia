import 'dart:math';

import '../models/bot_style.dart';
import '../models/card_model.dart';

enum HandType {
  single,
  pair,
  triple,
  sequence,
  threeDoubleSequence,
  fourOfAKind,
  fourDoubleSequence,
  invalid,
}

class HandResult {
  final HandType type;
  final CardModel highestCard;
  final int length;

  HandResult(this.type, this.highestCard, this.length);
}

class TienLenLogic {
  static List<CardModel> sortCards(List<CardModel> cards) {
    List<CardModel> sorted = List.from(cards);
    sorted.sort((a, b) => a.value.compareTo(b.value));
    return sorted;
  }

  static HandResult analyzeHand(List<CardModel> selected) {
    if (selected.isEmpty)
      return HandResult(
        HandType.invalid,
        CardModel(rank: CardRank.three, suit: CardSuit.spade),
        0,
      );
    List<CardModel> sorted = sortCards(selected);
    int len = sorted.length;
    CardModel highest = sorted.last;

    if (len == 1) return HandResult(HandType.single, highest, 1);
    if (len == 2 && sorted[0].rank == sorted[1].rank)
      return HandResult(HandType.pair, highest, 2);
    if (len == 3 &&
        sorted[0].rank == sorted[1].rank &&
        sorted[1].rank == sorted[2].rank)
      return HandResult(HandType.triple, highest, 3);
    if (len == 4 && sorted[0].rank == sorted[3].rank)
      return HandResult(HandType.fourOfAKind, highest, 4);

    if (len >= 3) {
      bool isSeq = true;
      for (int i = 0; i < len - 1; i++) {
        if (sorted[i].rank.index + 1 != sorted[i + 1].rank.index ||
            sorted[i + 1].rank == CardRank.two) {
          isSeq = false;
          break;
        }
      }
      if (isSeq) return HandResult(HandType.sequence, highest, len);
    }

    if (len >= 6 && len % 2 == 0) {
      bool isDoubleSeq = true;
      for (int i = 0; i < len; i += 2) {
        if (sorted[i].rank != sorted[i + 1].rank) {
          isDoubleSeq = false;
          break;
        }
        if (i + 2 < len &&
            (sorted[i].rank.index + 1 != sorted[i + 2].rank.index ||
                sorted[i + 2].rank == CardRank.two)) {
          isDoubleSeq = false;
          break;
        }
      }
      if (isDoubleSeq) {
        if (len == 6)
          return HandResult(HandType.threeDoubleSequence, highest, 6);
        if (len == 8)
          return HandResult(HandType.fourDoubleSequence, highest, 8);
      }
    }
    return HandResult(HandType.invalid, highest, 0);
  }

  static bool canPlay(
    List<CardModel> lastPlayed,
    List<CardModel> selected,
    bool isNewRound, {
    bool isFirstTurn = false,
    CardModel? mandatoryCard,
  }) {
    HandResult current = analyzeHand(selected);
    if (current.type == HandType.invalid) return false;

    // Luật ván đầu tiên: Phải có lá bài nhỏ nhất (mặc định 3 Bích)
    if (isFirstTurn) {
      final target =
          mandatoryCard ??
          CardModel(rank: CardRank.three, suit: CardSuit.spade);
      if (!selected.contains(target)) return false;
    }

    if (isNewRound || lastPlayed.isEmpty) return true;

    HandResult last = analyzeHand(lastPlayed);
    if (current.type == last.type && current.length == last.length)
      return current.highestCard.value > last.highestCard.value;

    if (current.type == HandType.fourOfAKind) {
      if (last.type == HandType.single && last.highestCard.rank == CardRank.two)
        return true;
      if (last.type == HandType.pair && last.highestCard.rank == CardRank.two)
        return true;
      if (last.type == HandType.threeDoubleSequence) return true;
    }

    if (current.type == HandType.threeDoubleSequence) {
      if (last.type == HandType.single && last.highestCard.rank == CardRank.two)
        return true;
    }

    if (current.type == HandType.fourDoubleSequence) {
      if (last.type == HandType.single && last.highestCard.rank == CardRank.two)
        return true;
      if (last.type == HandType.pair && last.highestCard.rank == CardRank.two)
        return true;
      if (last.type == HandType.fourOfAKind) return true;
      if (last.type == HandType.threeDoubleSequence) return true;
    }
    return false;
  }

  // --- GỢI Ý THÔNG MINH ---
  static List<CardModel> getSuggestedCards(
    CardModel tappedCard,
    List<CardModel> myHand,
    List<CardModel> lastPlayed,
  ) {
    if (lastPlayed.isEmpty) return [tappedCard];

    HandResult last = analyzeHand(lastPlayed);
    List<CardModel> sortedHand = sortCards(myHand);

    // 1. Gợi ý Đôi/Sám
    if (last.type == HandType.pair || last.type == HandType.triple) {
      List<CardModel> sameRank = sortedHand
          .where((c) => c.rank == tappedCard.rank)
          .toList();
      if (sameRank.length >= last.length) {
        // Lấy bộ cùng rank có chứa lá vừa chọn, ưu tiên lá to nhất để đủ chặt
        if (analyzeHand(sameRank.sublist(0, last.length)).highestCard.value >
            last.highestCard.value) {
          return sameRank.sublist(0, last.length);
        }
      }
    }

    // 2. Gợi ý Sảnh
    if (last.type == HandType.sequence) {
      // Tìm sảnh độ dài tương đương có chứa tappedCard
      List<CardModel> possibleSeq = [];
      // (Logic tìm sảnh phức tạp hơn, tạm thời chỉ tìm sảnh đơn giản chứa tappedCard)
      for (int i = 0; i <= sortedHand.length - last.length; i++) {
        List<CardModel> sub = sortedHand.sublist(i, i + last.length);
        HandResult res = analyzeHand(sub);
        if (res.type == HandType.sequence &&
            res.length == last.length &&
            sub.contains(tappedCard)) {
          if (res.highestCard.value > last.highestCard.value) return sub;
        }
      }
    }

    // 3. Gợi ý chặt Heo bằng Tứ quý/Đôi thông (Nếu chọn 1 lá rank tương ứng)
    if (last.type == HandType.single && last.highestCard.rank == CardRank.two) {
      // Nếu người chơi chọn 1 lá mà lá đó nằm trong 1 bộ Tứ quý có sẵn
      List<CardModel> fourOfAKind = sortedHand
          .where((c) => c.rank == tappedCard.rank)
          .toList();
      if (fourOfAKind.length == 4) return fourOfAKind;
    }

    return [tappedCard];
  }

  static bool checkInstantWin(List<CardModel> hand) {
    List<CardModel> sorted = sortCards(hand);
    if (sorted.where((c) => c.rank == CardRank.two).length == 4) return true;
    int pairs = 0;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i].rank == sorted[i + 1].rank) {
        pairs++;
        i++;
      }
    }
    if (pairs >= 6) return true;
    bool hasDragon = true;
    for (int i = 0; i < 12; i++) {
      if (!sorted.any((c) => c.rank.index == i)) {
        hasDragon = false;
        break;
      }
    }
    return hasDragon;
  }

  // ====================================================================
  // BOT LOGIC (AI) — "VIP PRO"
  // Nâng cấp: đè được mọi loại bộ (kể cả 3/4 đôi thông, tứ quý), chặt heo/bom
  // thông minh, ĐẾM BÀI (suy ra lá đối thủ còn giữ để biết nước "vô đối"),
  // và bớt thụ động (đè khi đáng thay vì bỏ lượt vô cớ).
  // Mọi nước trả về đều được đối chiếu với canPlay/analyzeHand để chắc chắn hợp lệ.
  // ====================================================================
  static List<CardModel> findBestMove({
    required List<CardModel> hand,
    required List<CardModel> lastPlayed,
    required bool isNewRound,
    required int opponentCardsLeft,
    required List<CardModel> playedCards,
    BotStyle style = BotStyle.balanced,
    CardModel? mandatoryCard,
  }) {
    if (hand.isEmpty) return <CardModel>[];

    final sortedHand = sortCards(hand); // tăng dần theo value
    final random = Random();

    // ---------- Tiện ích chung ----------
    int topValue(List<CardModel> cs) =>
        cs.map((c) => c.value).reduce((a, b) => a > b ? a : b);

    bool hasTwo(List<CardModel> cand) => cand.any((c) => c.rank == CardRank.two);

    // Bom = tứ quý / 3 đôi thông / 4 đôi thông (bài "điều khiển", nên giữ).
    bool isBomb(List<CardModel> cand) {
      final t = analyzeHand(cand).type;
      return t == HandType.fourOfAKind ||
          t == HandType.threeDoubleSequence ||
          t == HandType.fourDoubleSequence;
    }

    // Nước [cand] có hợp lệ để đè bài hiện tại không (đúng luật canPlay).
    bool beats(List<CardModel> cand) => canPlay(lastPlayed, cand, false);

    bool shouldAggressive() {
      if (opponentCardsLeft <= 3) return true;
      if (style == BotStyle.aggressive) return true;
      return false;
    }

    // Thỉnh thoảng chơi "như người" cho đỡ máy móc (đặt 0 nếu muốn mạnh tối đa).
    bool doSuboptimalMove() {
      if (style == BotStyle.troll) return true;
      return random.nextDouble() < 0;
    }

    Map<int, List<CardModel>> groupByRank(List<CardModel> cards) {
      final g = <int, List<CardModel>>{};
      for (final c in cards) g.putIfAbsent(c.rank.index, () => []).add(c);
      return g;
    }

    // ========== ĐẾM BÀI ==========
    // Tập lá đối thủ CÓ THỂ còn giữ = 52 lá − đã đánh − bài trên tay mình.
    // (Bàn 2-3 người: pool gồm cả lá không được chia → bot chỉ "thận trọng hơn",
    //  không bao giờ tự tin sai. "Vô đối" = chắc chắn không ai đè được bằng cùng loại.)
    List<CardModel> computeOppPool() {
      final out = <CardModel>[];
      for (final rank in CardRank.values) {
        for (final suit in CardSuit.values) {
          final inHand = hand.any((h) => h.rank == rank && h.suit == suit);
          final played =
              playedCards.any((p) => p.rank == rank && p.suit == suit);
          if (!inHand && !played) out.add(CardModel(rank: rank, suit: suit));
        }
      }
      return out;
    }

    final oppPool = computeOppPool();
    final oppByRank = groupByRank(oppPool);
    final oppMaxValue = oppPool.isEmpty
        ? -1
        : oppPool.map((c) => c.value).reduce((a, b) => a > b ? a : b);

    // Lá đơn vô đối: không lá đơn nào của đối thủ lớn hơn.
    bool singleUnbeatable(CardModel c) => c.value > oppMaxValue;

    // Đối thủ có thể tạo ĐÔI/SÁM (n lá cùng rank) đỉnh > v không?
    bool oppCanBeatNOfRank(int n, int v) {
      for (final cs in oppByRank.values) {
        if (cs.length >= n) {
          final top = cs.map((c) => c.value).reduce((a, b) => a > b ? a : b);
          if (top > v) return true;
        }
      }
      return false;
    }

    // Đối thủ có thể tạo SẢNH cùng độ dài [len] với đỉnh > v không?
    bool oppCanBeatSeq(int len, int v) {
      for (int start = 0; start + len - 1 <= CardRank.ace.index; start++) {
        bool ok = true;
        for (int r = start; r < start + len; r++) {
          if (!(oppByRank[r]?.isNotEmpty ?? false)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        final topRank = start + len - 1;
        final top = oppByRank[topRank]!
            .map((c) => c.value)
            .reduce((a, b) => a > b ? a : b);
        if (top > v) return true;
      }
      return false;
    }

    // Nước [cand] "vô đối" (không ai đè được bằng nước CÙNG LOẠI).
    bool moveUnbeatable(List<CardModel> cand) {
      final h = analyzeHand(cand);
      switch (h.type) {
        case HandType.single:
          return singleUnbeatable(cand.first);
        case HandType.pair:
          return !oppCanBeatNOfRank(2, h.highestCard.value);
        case HandType.triple:
          return !oppCanBeatNOfRank(3, h.highestCard.value);
        case HandType.sequence:
          return !oppCanBeatSeq(cand.length, h.highestCard.value);
        default:
          return false; // bom: về lý thuyết vẫn có thể bị bom lớn hơn
      }
    }

    // ========== SINH CÁC BỘ ==========
    List<List<CardModel>> allFourKinds() {
      final g = groupByRank(sortedHand);
      final res = <List<CardModel>>[];
      for (final r in g.keys.toList()..sort()) {
        if (g[r]!.length == 4) res.add(List<CardModel>.from(g[r]!));
      }
      return res;
    }

    List<List<CardModel>> beatingFourKinds(int v) =>
        allFourKinds().where((m) => topValue(m) > v).toList();

    // Đôi thông [pairCount] cặp (3 → 3 đôi thông, 4 → 4 đôi thông).
    // Rank đỉnh lấy 2 lá CAO nhất để đè chắc; các rank khác lấy 2 lá thấp nhất.
    List<List<CardModel>> doubleSeqs(int pairCount) {
      final g = groupByRank(sortedHand);
      final res = <List<CardModel>>[];
      for (int start = 0;
          start + pairCount - 1 <= CardRank.ace.index;
          start++) {
        bool ok = true;
        for (int r = start; r < start + pairCount; r++) {
          if ((g[r]?.length ?? 0) < 2) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        final seq = <CardModel>[];
        for (int r = start; r < start + pairCount; r++) {
          final cs = g[r]!;
          if (r == start + pairCount - 1) {
            seq.add(cs[cs.length - 2]);
            seq.add(cs[cs.length - 1]);
          } else {
            seq.add(cs[0]);
            seq.add(cs[1]);
          }
        }
        res.add(seq);
      }
      return res;
    }

    List<List<CardModel>> beatingDoubleSeqs(int pairCount, int v) =>
        doubleSeqs(pairCount).where((m) => topValue(m) > v).toList();

    // Các ĐÔI thắng được mốc value [v] — lấy 2 lá cao nhất của rank để đè chắc.
    List<List<CardModel>> beatingPairs(int v) {
      final g = groupByRank(sortedHand);
      final res = <List<CardModel>>[];
      for (final r in g.keys.toList()..sort()) {
        final cs = g[r]!;
        if (cs.length >= 2) {
          final hi = cs[cs.length - 1];
          final lo = cs[cs.length - 2];
          if (hi.value > v) res.add([lo, hi]);
        }
      }
      return res;
    }

    // Các SÁM thắng được mốc value [v].
    List<List<CardModel>> beatingTriples(int v) {
      final g = groupByRank(sortedHand);
      final res = <List<CardModel>>[];
      for (final r in g.keys.toList()..sort()) {
        final cs = g[r]!;
        if (cs.length >= 3 && cs[2].value > v) res.add([cs[0], cs[1], cs[2]]);
      }
      return res;
    }

    // Sinh mọi sảnh độ dài [len] (rank 3..A, KHÔNG có 2): lá dưới lấy suit thấp,
    // lá đỉnh lấy suit cao (dễ đè nhất). Xử lý đúng cả khi bài có rank trùng.
    List<List<CardModel>> sequencesOfLength(int len) {
      final g = <int, List<CardModel>>{};
      for (final c in sortedHand) {
        if (c.rank == CardRank.two) continue;
        g.putIfAbsent(c.rank.index, () => []).add(c);
      }
      final res = <List<CardModel>>[];
      for (int start = 0; start + len - 1 <= CardRank.ace.index; start++) {
        bool ok = true;
        for (int r = start; r < start + len; r++) {
          if (!(g[r]?.isNotEmpty ?? false)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        final seq = <CardModel>[];
        for (int r = start; r < start + len; r++) {
          seq.add(r == start + len - 1 ? g[r]!.last : g[r]!.first);
        }
        res.add(seq);
      }
      return res;
    }

    // ========== PHÂN RÃ BÀI THÀNH CÁC BỘ ==========
    // Ước lượng "số lượt còn lại để hết bài". Ưu tiên giữ tứ quý & đôi thông
    // làm bom (mỗi bom 1 lượt), rồi rút đôi thông / sảnh dài nhất, phần dư gom
    // theo rank. Mỗi bộ tính là 1 lượt ra bài.
    List<List<CardModel>> planMelds(List<CardModel> cards) {
      final melds = <List<CardModel>>[];
      if (cards.isEmpty) return melds;
      final pool = sortCards(cards);
      final used = List<bool>.filled(pool.length, false);

      Map<int, List<int>> groupUnused() {
        final g = <int, List<int>>{};
        for (int i = 0; i < pool.length; i++) {
          if (!used[i]) g.putIfAbsent(pool[i].rank.index, () => []).add(i);
        }
        return g;
      }

      // 1) Tứ quý → 1 bộ (giữ làm bom).
      {
        final g = groupUnused();
        for (final r in g.keys.toList()..sort()) {
          if (g[r]!.length == 4) {
            melds.add([for (final i in g[r]!) pool[i]]);
            for (final i in g[r]!) used[i] = true;
          }
        }
      }

      // 2) Đôi thông dài nhất (≥3 cặp rank liên tiếp, ≠2) → 1 bộ.
      while (true) {
        final g = groupUnused();
        List<int> bestRanks = <int>[];
        for (int start = 0; start <= CardRank.ace.index; start++) {
          final run = <int>[];
          for (int r = start; r <= CardRank.ace.index; r++) {
            if ((g[r]?.length ?? 0) >= 2)
              run.add(r);
            else
              break;
          }
          if (run.length > bestRanks.length) bestRanks = List<int>.from(run);
        }
        if (bestRanks.length >= 3) {
          final meld = <CardModel>[];
          for (final r in bestRanks) {
            meld.add(pool[g[r]![0]]);
            meld.add(pool[g[r]![1]]);
            used[g[r]![0]] = true;
            used[g[r]![1]] = true;
          }
          melds.add(meld);
        } else {
          break;
        }
      }

      // 3) Sảnh dài nhất (≠2) → 1 bộ.
      while (true) {
        final g = groupUnused();
        List<int> bestRanks = <int>[];
        for (int start = 0; start <= CardRank.ace.index; start++) {
          final run = <int>[];
          for (int r = start; r <= CardRank.ace.index; r++) {
            if (g[r]?.isNotEmpty ?? false)
              run.add(r);
            else
              break;
          }
          if (run.length > bestRanks.length) bestRanks = List<int>.from(run);
        }
        if (bestRanks.length >= 3) {
          final meld = <CardModel>[];
          for (final r in bestRanks) {
            final i = g[r]![0];
            meld.add(pool[i]);
            used[i] = true;
          }
          melds.add(meld);
        } else {
          break;
        }
      }

      // 4) Phần dư gom theo rank (sám / đôi / lẻ).
      {
        final g = groupUnused();
        for (final r in g.keys.toList()..sort()) {
          melds.add([for (final i in g[r]!) pool[i]]);
        }
      }
      return melds;
    }

    int planCount(List<CardModel> cards) => planMelds(cards).length;
    final baseCount = planCount(sortedHand);

    // Đánh nước [cand] có "sạch" không (không làm tăng số lượt còn lại).
    bool isClean(List<CardModel> cand) {
      final remaining = sortedHand.where((c) => !cand.contains(c)).toList();
      return planCount(remaining) <= baseCount - 1;
    }

    // Đánh [cand] làm "vỡ" thêm bao nhiêu bộ so với mức lý tưởng (0 = sạch).
    int breakCost(List<CardModel> cand) {
      final remaining = sortedHand.where((c) => !cand.contains(c)).toList();
      return planCount(remaining) - (baseCount - 1);
    }

    // Sau khi dùng [bomb], phần bài còn lại có toàn nước "vô đối"/bom không
    // (tức gần như cầm chắc về) → khi đó đáng để nổ bom.
    bool afterBombDominant(List<CardModel> bomb) {
      final remaining = sortedHand.where((c) => !bomb.contains(c)).toList();
      if (remaining.isEmpty) return true;
      final rem = planMelds(remaining);
      return rem.every((m) => moveUnbeatable(m) || isBomb(m));
    }

    // ========== QUYẾT ĐỊNH KHI THEO BÀI ==========
    // rawCands: các nước có thể thắng. Lọc qua canPlay rồi sắp tăng theo độ mạnh.
    List<CardModel> respond(List<List<CardModel>> rawCands, CardModel leadHigh) {
      final cands = rawCands.where(beats).toList()
        ..sort((a, b) => topValue(a) - topValue(b));
      if (cands.isEmpty) return <CardModel>[];

      // Cuối ván: đối thủ còn ≤2 lá → đè con CAO NHẤT để khóa, không cho ra bài.
      if (opponentCardsLeft <= 2) return cands.last;

      final lastIsTwo = leadHigh.rank == CardRank.two;
      final forced =
          shouldAggressive() || opponentCardsLeft <= 3 || hand.length <= 5;

      // 1) Nước rẻ nhất KHÔNG vỡ bộ & KHÔNG phí heo/bom.
      for (final cand in cands) {
        if (isClean(cand) && !hasTwo(cand) && !isBomb(cand)) {
          // Đôi khi "câu bài": bỏ lượt với mấy lá thấp vô thưởng vô phạt.
          if (style != BotStyle.aggressive &&
              opponentCardsLeft > 4 &&
              hand.length > 6 &&
              leadHigh.rank.index <= CardRank.seven.index &&
              doSuboptimalMove()) {
            return <CardModel>[];
          }
          return cand;
        }
      }

      // 2) Đè HEO bằng nước thường (không bom) → luôn đáng để cướp quyền ra bài.
      if (lastIsTwo) {
        for (final cand in cands) {
          if (!isBomb(cand) && !hasTwo(cand)) return cand;
        }
      }

      // 3) Chấp nhận hơi vỡ bộ để GIÀNH QUYỀN (lì hơn bản cũ), miễn không phí
      //    heo/bom và ván đang đáng tranh. Trả nước RẺ NHẤT thỏa điều kiện.
      for (final cand in cands) {
        if (hasTwo(cand) || isBomb(cand)) continue;
        final cost = breakCost(cand);
        if (cost <= 0) return cand; // sạch (phòng hờ)
        final worthIt = forced ||
            opponentCardsLeft <= 6 ||
            hand.length <= 8 ||
            moveUnbeatable(cand);
        if (cost <= 1 && worthIt) return cand;
      }

      // 4) Bị ép → dùng nước rẻ nhất, ưu tiên heo thường, tránh bom nếu được.
      if (forced) {
        for (final cand in cands) {
          if (!isBomb(cand)) return cand;
        }
        return cands.first;
      }

      // 5) Còn lại: GIỮ bài, bỏ lượt để bảo toàn bộ & để dành heo/bom điều khiển.
      return <CardModel>[];
    }

    // ==================================
    // KHAI CUỘC / CẦM CÁI (được quyền ra bài tự do)
    // ==================================
    if (isNewRound || lastPlayed.isEmpty) {
      // Nước đầu tiên của cả ván: bắt buộc chứa lá mở (mặc định 3 bích).
      if (playedCards.isEmpty) {
        final target = mandatoryCard ??
            CardModel(rank: CardRank.three, suit: CardSuit.spade);
        // Ưu tiên sảnh DÀI NHẤT có chứa lá mở → xả được nhiều nhất.
        for (int len = 12; len >= 3; len--) {
          for (final seq in sequencesOfLength(len)) {
            if (seq.any((c) => c.rank == target.rank && c.suit == target.suit)) {
              return seq;
            }
          }
        }
        // Hoặc đôi cùng rank với lá mở.
        final same = sortedHand.where((c) => c.rank == target.rank).toList();
        if (same.length >= 2 && same.any((c) => c.suit == target.suit)) {
          final tgt = same.firstWhere((c) => c.suit == target.suit);
          final mate = same.firstWhere((c) => c.suit != target.suit);
          return [tgt, mate];
        }
        // Hết cách thì đánh đúng lá mở.
        return [
          sortedHand.firstWhere(
            (c) => c.rank == target.rank && c.suit == target.suit,
            orElse: () => sortedHand.first,
          )
        ];
      }

      final melds = planMelds(sortedHand);

      // Cả bài chỉ còn đúng 1 bộ → đánh hết để THẮNG luôn.
      if (melds.length <= 1) return sortedHand;

      // Tách bom (giữ điều khiển) khỏi các bộ "thường".
      final nonBomb = melds.where((m) => !isBomb(m)).toList();

      int byTop(List<CardModel> a, List<CardModel> b) =>
          topValue(a) - topValue(b);

      // Đối thủ sắp về (≤2 lá): tống nước VÔ ĐỐI cao nhất để chặn họ ra bài;
      // không có nước vô đối thì ra con cao nhất ép họ bỏ lượt.
      if (opponentCardsLeft <= 2) {
        final unbeatableSingles =
            sortedHand.where((c) => singleUnbeatable(c)).toList()
              ..sort((a, b) => b.value - a.value);
        if (unbeatableSingles.isNotEmpty) return [unbeatableSingles.first];
        return [sortedHand.last];
      }

      // Có nước VÔ ĐỐI nhiều lá (sảnh/đôi/sám) → đi để xả nhiều & giữ trịch.
      final unbeatableMelds =
          nonBomb.where((m) => m.length >= 2 && moveUnbeatable(m)).toList()
            ..sort((a, b) => b.length - a.length);
      if (unbeatableMelds.isNotEmpty &&
          (opponentCardsLeft <= 6 || unbeatableMelds.first.length >= 3)) {
        return unbeatableMelds.first;
      }

      // Còn lại: xả "rác" trước, giữ heo & bom làm bài điều khiển.
      // Thứ tự: lẻ thấp (≠2) → đôi thấp (≠2) → sảnh thấp → sám thấp (≠2).
      final pool = nonBomb.isNotEmpty ? nonBomb : melds;

      final singles = pool
          .where((m) => m.length == 1 && m.first.rank != CardRank.two)
          .toList()
        ..sort(byTop);
      if (singles.isNotEmpty) return singles.first;

      final pairs = pool
          .where((m) =>
              m.length == 2 &&
              m.first.rank == m.last.rank &&
              m.first.rank != CardRank.two)
          .toList()
        ..sort(byTop);
      if (pairs.isNotEmpty) return pairs.first;

      final seqs = pool
          .where((m) => m.length >= 3 && m.first.rank != m.last.rank)
          .toList()
        ..sort(byTop);
      if (seqs.isNotEmpty) return seqs.first;

      final triples = pool
          .where((m) =>
              m.length == 3 &&
              m.first.rank == m.last.rank &&
              m.first.rank != CardRank.two)
          .toList()
        ..sort(byTop);
      if (triples.isNotEmpty) return triples.first;

      // Bí lắm (tay chỉ còn heo/bom): đánh nguyên BỘ đầu tiên thay vì xé lẻ,
      // để không phá vỡ bom & vẫn ra nước hợp lệ.
      return melds.first;
    }

    // ==================================
    // THEO BÀI
    // ==================================
    final last = analyzeHand(lastPlayed);

    switch (last.type) {
      case HandType.single:
        final cands = [
          for (final c in sortedHand)
            if (c.value > last.highestCard.value) [c]
        ];
        final r = respond(cands, last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      case HandType.pair:
        final r =
            respond(beatingPairs(last.highestCard.value), last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      case HandType.triple:
        final r =
            respond(beatingTriples(last.highestCard.value), last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      case HandType.sequence:
        final cands = [
          for (final seq in sequencesOfLength(lastPlayed.length))
            if (topValue(seq) > last.highestCard.value) seq
        ];
        final r = respond(cands, last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      case HandType.threeDoubleSequence:
        final r = respond(
            beatingDoubleSeqs(3, last.highestCard.value), last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      case HandType.fourOfAKind:
        final r =
            respond(beatingFourKinds(last.highestCard.value), last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      case HandType.fourDoubleSequence:
        final r = respond(
            beatingDoubleSeqs(4, last.highestCard.value), last.highestCard);
        if (r.isNotEmpty) return r;
        break;

      default:
        break;
    }

    // ==================================
    // CHẶT HEO / CHẶT BOM THÔNG MINH
    // Theo đúng luật canPlay: heo lẻ ← 3 đôi thông / tứ quý / 4 đôi thông;
    // đôi heo ← tứ quý / 4 đôi thông; tứ quý ← 4 đôi thông; 3 đôi thông ←
    // tứ quý / 4 đôi thông. Chọn "bom" rẻ nhất đủ chặt, chỉ chặt khi đáng.
    // ==================================
    final leadIsSingleTwo =
        last.type == HandType.single && last.highestCard.rank == CardRank.two;
    final leadIsPairTwo =
        last.type == HandType.pair && last.highestCard.rank == CardRank.two;
    final leadIsFourKind = last.type == HandType.fourOfAKind;
    final leadIsThreeDoubleSeq = last.type == HandType.threeDoubleSequence;

    if (leadIsSingleTwo ||
        leadIsPairTwo ||
        leadIsFourKind ||
        leadIsThreeDoubleSeq) {
      // Gom mọi loại bom rồi lọc qua canPlay để chỉ giữ nước hợp lệ.
      final candidates = <List<CardModel>>[];
      candidates.addAll(doubleSeqs(3)); // 3 đôi thông
      candidates.addAll(allFourKinds()); // tứ quý
      candidates.addAll(doubleSeqs(4)); // 4 đôi thông

      // Ưu tiên dùng bom "ít quý" trước: 3 đôi thông → tứ quý → 4 đôi thông,
      // cùng loại thì topValue thấp trước (để dành lá to).
      int bombRank(List<CardModel> b) {
        final t = analyzeHand(b).type;
        if (t == HandType.threeDoubleSequence) return 0;
        if (t == HandType.fourOfAKind) return 1;
        return 2; // fourDoubleSequence
      }

      final usable = candidates.where(beats).toList()
        ..sort((a, b) {
          final r = bombRank(a) - bombRank(b);
          if (r != 0) return r;
          return topValue(a) - topValue(b);
        });

      if (usable.isNotEmpty) {
        final bomb = usable.first;
        final worthIt = leadIsPairTwo ||
            leadIsFourKind ||
            leadIsThreeDoubleSeq || // nước mạnh + được ăn tiền chặt → nên cướp
            shouldAggressive() ||
            hand.length <= 7 ||
            opponentCardsLeft <= 4 ||
            afterBombDominant(bomb); // chặt xong là về chắc
        if (worthIt) return bomb;
      }
    }

    // Không đánh được / chủ động giữ bài → bỏ lượt.
    return <CardModel>[];
  }
}
