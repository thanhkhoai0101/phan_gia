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

  // --- BOT LOGIC (AI) ---
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

    bool sameRank(List<CardModel> cards, int start, int count) {
      for (int i = start; i < start + count - 1; i++) {
        if (cards[i].rank != cards[i + 1].rank) return false;
      }
      return true;
    }

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

    List<CardModel> findFourKind() {
      for (int i = 0; i < sortedHand.length - 3; i++) {
        if (sameRank(sortedHand, i, 4)) {
          return sortedHand.sublist(i, i + 4);
        }
      }
      return <CardModel>[];
    }

    // ===== PHÂN RÃ BÀI THÀNH CÁC BỘ =====
    // Rút sảnh DÀI NHẤT trước (xả được nhiều lá nhất). Phần còn lại gom theo rank:
    // 4 lá = tứ quý, 3 = sám, 2 = đôi, 1 = lẻ. Mỗi bộ tính là 1 lượt ra bài.
    List<List<CardModel>> planMelds(List<CardModel> cards) {
      final melds = <List<CardModel>>[];
      if (cards.isEmpty) return melds;
      final pool = sortCards(cards);
      final used = List<bool>.filled(pool.length, false);

      while (true) {
        List<int> best = <int>[];
        // Sảnh chỉ gồm rank 3..A (KHÔNG có 2). Thử mọi điểm bắt đầu, lấy chuỗi dài nhất.
        for (int start = 0; start <= CardRank.ace.index; start++) {
          final run = <int>[];
          for (int r = start; r <= CardRank.ace.index; r++) {
            int found = -1;
            for (int i = 0; i < pool.length; i++) {
              if (!used[i] && pool[i].rank.index == r) {
                found = i;
                break;
              }
            }
            if (found == -1) break;
            run.add(found);
          }
          if (run.length > best.length) best = List<int>.from(run);
        }
        if (best.length < 3) break;
        melds.add([for (final i in best) pool[i]]);
        for (final i in best) used[i] = true;
      }

      final rem = <int, List<CardModel>>{};
      for (int i = 0; i < pool.length; i++) {
        if (!used[i]) rem.putIfAbsent(pool[i].rank.index, () => []).add(pool[i]);
      }
      for (final k in rem.keys.toList()..sort()) {
        melds.add(rem[k]!);
      }
      return melds;
    }

    int planCount(List<CardModel> cards) => planMelds(cards).length;
    final baseCount = planCount(sortedHand);

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

    // Các ĐÔI thắng được mốc value [v] (tăng dần theo độ mạnh).
    List<List<CardModel>> beatingPairs(int v) {
      final g = <int, List<CardModel>>{};
      for (final c in sortedHand) g.putIfAbsent(c.rank.index, () => []).add(c);
      final res = <List<CardModel>>[];
      for (final r in g.keys.toList()..sort()) {
        final cs = g[r]!;
        if (cs.length >= 2 && cs[1].value > v) res.add([cs[0], cs[1]]);
      }
      return res;
    }

    // Các SÁM (bộ ba) thắng được mốc value [v].
    List<List<CardModel>> beatingTriples(int v) {
      final g = <int, List<CardModel>>{};
      for (final c in sortedHand) g.putIfAbsent(c.rank.index, () => []).add(c);
      final res = <List<CardModel>>[];
      for (final r in g.keys.toList()..sort()) {
        final cs = g[r]!;
        if (cs.length >= 3 && cs[2].value > v) res.add([cs[0], cs[1], cs[2]]);
      }
      return res;
    }

    int topValue(List<CardModel> cs) =>
        cs.map((c) => c.value).reduce((a, b) => a > b ? a : b);

    bool hasTwo(List<CardModel> cand) => cand.any((c) => c.rank == CardRank.two);

    // Đánh nước [cand] có làm "vỡ bộ" không? Sạch = số bộ còn lại giảm đúng 1.
    bool isClean(List<CardModel> cand) {
      final remaining = sortedHand.where((c) => !cand.contains(c)).toList();
      return planCount(remaining) <= baseCount - 1;
    }

    // ===== QUYẾT ĐỊNH KHI THEO BÀI =====
    // cands: các nước thắng được, đã sắp tăng dần theo độ mạnh.
    // leadHigh: lá cao nhất của bài đối thủ vừa đánh.
    List<CardModel> respond(List<List<CardModel>> cands, CardModel leadHigh) {
      if (cands.isEmpty) return <CardModel>[];

      // Cuối ván: đối thủ còn ≤2 lá -> đè con CAO NHẤT để khóa, không cho ra bài.
      if (opponentCardsLeft <= 2) return cands.last;

      final forced =
          shouldAggressive() || opponentCardsLeft <= 3 || hand.length <= 4;
      final lastIsTwo = leadHigh.rank == CardRank.two;

      // 1) Nước rẻ nhất mà KHÔNG vỡ bộ và KHÔNG phí heo.
      for (final cand in cands) {
        if (isClean(cand) && !hasTwo(cand)) {
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

      // 2) Đè heo bằng heo thì luôn đáng (cướp quyền ra bài).
      if (lastIsTwo) {
        for (final cand in cands) {
          if (isClean(cand)) return cand;
        }
      }

      // 3) Bị ép (cuối ván / bài ít / style gắt) -> ăn nước rẻ nhất, ưu tiên không vỡ bộ.
      if (forced) {
        for (final cand in cands) {
          if (isClean(cand)) return cand;
        }
        return cands.first;
      }

      // 4) Còn lại: GIỮ bài, bỏ lượt để bảo toàn bộ & để dành heo/tứ quý điều khiển.
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
        // Ưu tiên sảnh DÀI NHẤT có chứa lá mở -> xả được nhiều nhất.
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

      // Cả bài chỉ còn đúng 1 bộ -> đánh hết để THẮNG luôn.
      if (melds.length <= 1) return sortedHand;

      // Đối thủ sắp về (≤2 lá) -> ra con cao nhất ép họ phải bỏ lượt.
      if (opponentCardsLeft <= 2) return [sortedHand.last];

      // Còn lại: xả "rác" trước, giữ heo & tứ quý làm bài điều khiển.
      // Thứ tự: lẻ thấp (≠2) -> đôi thấp (≠2) -> sảnh thấp -> sám thấp (≠2).
      int byTop(List<CardModel> a, List<CardModel> b) =>
          topValue(a) - topValue(b);

      final singles = melds
          .where((m) => m.length == 1 && m.first.rank != CardRank.two)
          .toList()
        ..sort(byTop);
      if (singles.isNotEmpty) return singles.first;

      final pairs = melds
          .where((m) =>
      m.length == 2 &&
          m.first.rank == m.last.rank &&
          m.first.rank != CardRank.two)
          .toList()
        ..sort(byTop);
      if (pairs.isNotEmpty) return pairs.first;

      final seqs = melds
          .where((m) => m.length >= 3 && m.first.rank != m.last.rank)
          .toList()
        ..sort(byTop);
      if (seqs.isNotEmpty) return seqs.first;

      final triples = melds
          .where((m) =>
      m.length == 3 &&
          m.first.rank == m.last.rank &&
          m.first.rank != CardRank.two)
          .toList()
        ..sort(byTop);
      if (triples.isNotEmpty) return triples.first;

      // Bí lắm thì đánh lá thấp nhất (có thể là 2 nếu chỉ còn 2).
      return [sortedHand.first];
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
        final r = respond(beatingPairs(last.highestCard.value), last.highestCard);
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

      default:
        break;
    }

    // ==================================
    // CHẶT HEO THÔNG MINH (tứ quý)
    // Tứ quý chặt được heo lẻ và đôi heo. Chỉ chặt khi đáng để khỏi phí bom.
    // (Nếu engine của bạn hỗ trợ 3/4 đôi thông thì cắm thêm logic chặt ở đây.)
    // ==================================
    final leadIsSingleTwo =
        last.type == HandType.single && last.highestCard.rank == CardRank.two;
    final leadIsPairTwo =
        last.type == HandType.pair && last.highestCard.rank == CardRank.two;

    if (leadIsSingleTwo || leadIsPairTwo) {
      final fk = findFourKind();
      if (fk.isNotEmpty) {
        final worthIt = leadIsPairTwo || // đôi heo rất mạnh -> nên chặt
            shouldAggressive() ||
            hand.length <= 7 ||
            opponentCardsLeft <= 4;
        if (worthIt) return fk;
      }
    }

    // Không đánh được / chủ động giữ bài -> bỏ lượt.
    return <CardModel>[];
  }
}
