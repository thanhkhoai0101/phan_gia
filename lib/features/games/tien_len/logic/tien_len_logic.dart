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
  invalid
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
    if (selected.isEmpty) return HandResult(HandType.invalid, CardModel(rank: CardRank.three, suit: CardSuit.spade), 0);
    List<CardModel> sorted = sortCards(selected);
    int len = sorted.length;
    CardModel highest = sorted.last;

    if (len == 1) return HandResult(HandType.single, highest, 1);
    if (len == 2 && sorted[0].rank == sorted[1].rank) return HandResult(HandType.pair, highest, 2);
    if (len == 3 && sorted[0].rank == sorted[1].rank && sorted[1].rank == sorted[2].rank) return HandResult(HandType.triple, highest, 3);
    if (len == 4 && sorted[0].rank == sorted[3].rank) return HandResult(HandType.fourOfAKind, highest, 4);

    if (len >= 3) {
      bool isSeq = true;
      for (int i = 0; i < len - 1; i++) {
        if (sorted[i].rank.index + 1 != sorted[i+1].rank.index || sorted[i+1].rank == CardRank.two) { isSeq = false; break; }
      }
      if (isSeq) return HandResult(HandType.sequence, highest, len);
    }

    if (len >= 6 && len % 2 == 0) {
      bool isDoubleSeq = true;
      for (int i = 0; i < len; i += 2) {
        if (sorted[i].rank != sorted[i+1].rank) { isDoubleSeq = false; break; }
        if (i + 2 < len && (sorted[i].rank.index + 1 != sorted[i+2].rank.index || sorted[i+2].rank == CardRank.two)) { isDoubleSeq = false; break; }
      }
      if (isDoubleSeq) {
        if (len == 6) return HandResult(HandType.threeDoubleSequence, highest, 6);
        if (len == 8) return HandResult(HandType.fourDoubleSequence, highest, 8);
      }
    }
    return HandResult(HandType.invalid, highest, 0);
  }

  static bool canPlay(List<CardModel> lastPlayed, List<CardModel> selected, bool isNewRound, {bool isFirstTurn = false, CardModel? mandatoryCard}) {
    HandResult current = analyzeHand(selected);
    if (current.type == HandType.invalid) return false;

    // Luật ván đầu tiên: Phải có lá bài nhỏ nhất (mặc định 3 Bích)
    if (isFirstTurn) {
      final target = mandatoryCard ?? CardModel(rank: CardRank.three, suit: CardSuit.spade);
      if (!selected.contains(target)) return false;
    }

    if (isNewRound || lastPlayed.isEmpty) return true;

    HandResult last = analyzeHand(lastPlayed);
    if (current.type == last.type && current.length == last.length) return current.highestCard.value > last.highestCard.value;

    if (current.type == HandType.fourOfAKind) {
      if (last.type == HandType.single && last.highestCard.rank == CardRank.two) return true;
      if (last.type == HandType.pair && last.highestCard.rank == CardRank.two) return true;
      if (last.type == HandType.threeDoubleSequence) return true;
    }

    if (current.type == HandType.threeDoubleSequence) {
      if (last.type == HandType.single && last.highestCard.rank == CardRank.two) return true;
    }

    if (current.type == HandType.fourDoubleSequence) {
      if (last.type == HandType.single && last.highestCard.rank == CardRank.two) return true;
      if (last.type == HandType.pair && last.highestCard.rank == CardRank.two) return true;
      if (last.type == HandType.fourOfAKind) return true;
      if (last.type == HandType.threeDoubleSequence) return true;
    }
    return false;
  }

  // --- GỢI Ý THÔNG MINH ---
  static List<CardModel> getSuggestedCards(CardModel tappedCard, List<CardModel> myHand, List<CardModel> lastPlayed) {
    if (lastPlayed.isEmpty) return [tappedCard];
    
    HandResult last = analyzeHand(lastPlayed);
    List<CardModel> sortedHand = sortCards(myHand);

    // 1. Gợi ý Đôi/Sám
    if (last.type == HandType.pair || last.type == HandType.triple) {
      List<CardModel> sameRank = sortedHand.where((c) => c.rank == tappedCard.rank).toList();
      if (sameRank.length >= last.length) {
        // Lấy bộ cùng rank có chứa lá vừa chọn, ưu tiên lá to nhất để đủ chặt
        if (analyzeHand(sameRank.sublist(0, last.length)).highestCard.value > last.highestCard.value) {
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
        if (res.type == HandType.sequence && res.length == last.length && sub.contains(tappedCard)) {
          if (res.highestCard.value > last.highestCard.value) return sub;
        }
      }
    }

    // 3. Gợi ý chặt Heo bằng Tứ quý/Đôi thông (Nếu chọn 1 lá rank tương ứng)
    if (last.type == HandType.single && last.highestCard.rank == CardRank.two) {
      // Nếu người chơi chọn 1 lá mà lá đó nằm trong 1 bộ Tứ quý có sẵn
      List<CardModel> fourOfAKind = sortedHand.where((c) => c.rank == tappedCard.rank).toList();
      if (fourOfAKind.length == 4) return fourOfAKind;
    }

    return [tappedCard];
  }

  static bool checkInstantWin(List<CardModel> hand) {
    List<CardModel> sorted = sortCards(hand);
    if (sorted.where((c) => c.rank == CardRank.two).length == 4) return true;
    int pairs = 0;
    for (int i = 0; i < sorted.length - 1; i++) { if (sorted[i].rank == sorted[i+1].rank) { pairs++; i++; } }
    if (pairs >= 6) return true;
    bool hasDragon = true;
    for (int i = 0; i < 12; i++) { if (!sorted.any((c) => c.rank.index == i)) { hasDragon = false; break; } }
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
  if (hand.isEmpty) return [];

  final sortedHand = sortCards(hand);
  final random = Random();

  bool sameRank(List<CardModel> cards, int start, int count) {
  for (int i = start; i < start + count - 1; i++) {
  if (cards[i].rank != cards[i + 1].rank) return false;
  }
  return true;
  }

  bool isPartOfCombo(CardModel card) {
  return sortedHand.where((c) => c.rank == card.rank).length >= 2;
  }

  bool isStrongCard(CardModel card) {
  return card.rank == CardRank.two ||
  card.rank == CardRank.ace;
  }

  bool shouldAggressive() {
  if (opponentCardsLeft <= 3) return true;
  if (style == BotStyle.aggressive) return true;
  return false;
  }

  List<CardModel> findFourKind() {
  for (int i = 0; i < sortedHand.length - 3; i++) {
  if (sameRank(sortedHand, i, 4)) {
  return sortedHand.sublist(i, i + 4);
  }
  }
  return [];
  }

  List<List<CardModel>> generateSequences(int len) {
  List<List<CardModel>> result = [];

  for (int i = 0; i <= sortedHand.length - len; i++) {
  final sub = sortedHand.sublist(i, i + len);

  if (analyzeHand(sub).type == HandType.sequence) {
  result.add(sub);
  }
  }

  return result;
  }

  List<CardModel> analyzeBestComboFinish() {
  for (int i = 0; i < sortedHand.length - 2; i++) {
  if (sameRank(sortedHand, i, 3)) {
  return sortedHand.sublist(i, i + 3);
  }
  }

  for (int i = 0; i < sortedHand.length - 1; i++) {
  if (sameRank(sortedHand, i, 2)) {
  return sortedHand.sublist(i, i + 2);
  }
  }

  return [sortedHand.first];
  }

  bool shouldHoldStrong(CardModel card) {
  if (style == BotStyle.aggressive) return false;
  return isStrongCard(card);
  }

  // ==================================
  // HUMANIZATION RANDOMNESS
  // ==================================
  bool doSuboptimalMove() {
  if (style == BotStyle.troll) return true;
  return random.nextDouble() < 0.12;
  }

  // ==================================
  // OPEN ROUND
  // ==================================
  if (isNewRound || lastPlayed.isEmpty) {
  // Luật khai cuộc: Nếu chưa ai đánh lá nào trong ván này
  if (playedCards.isEmpty) {
  final target = mandatoryCard ?? CardModel(rank: CardRank.three, suit: CardSuit.spade);
  for (int len = 13; len >= 3; len--) {
  for (final seq in generateSequences(len)) {
  if (seq.contains(target)) return seq;
  }
  }
  for (int i = 0; i < sortedHand.length - 1; i++) {
  if (sameRank(sortedHand, i, 2) && sortedHand[i].rank == target.rank) {
  if (sortedHand.sublist(i, i+2).contains(target)) return sortedHand.sublist(i, i+2);
  }
  }
  return [sortedHand.firstWhere((c) => c == target, orElse: () => sortedHand.first)];
  }

  if (hand.length <= 5) {
  return analyzeBestComboFinish();
  }

  for (final card in sortedHand) {
  if (!isPartOfCombo(card) &&
  !shouldHoldStrong(card)) {
  return [card];
  }
  }

  for (int i = 0; i < sortedHand.length - 1; i++) {
  if (sameRank(sortedHand, i, 2)) {
  return sortedHand.sublist(i, i + 2);
  }
  }

  return [sortedHand.first];
  }

  final last = analyzeHand(lastPlayed);

  // ==================================
  // BLOCK ENDGAME HARD
  // ==================================
  if (opponentCardsLeft <= 2) {
  switch (last.type) {
  case HandType.single:
  for (final card in sortedHand.reversed) {
  if (card.value > last.highestCard.value) {
  return [card];
  }
  }
  break;

  case HandType.pair:
  for (int i = sortedHand.length - 2; i >= 0; i--) {
  if (sameRank(sortedHand, i, 2) &&
  sortedHand[i + 1].value > last.highestCard.value) {
  return sortedHand.sublist(i, i + 2);
  }
  }
  break;

  default:
  break;
  }
  }

  // ==================================
  // NORMAL RESPONSE
  // ==================================
  switch (last.type) {
  case HandType.single:
  for (final card in sortedHand) {
  if (card.value > last.highestCard.value) {
  if (!shouldAggressive() &&
  shouldHoldStrong(card)) {
  continue;
  }

  if (doSuboptimalMove() &&
  card.value > last.highestCard.value + 4) {
  continue;
  }

  return [card];
  }
  }
  break;

  case HandType.pair:
  for (int i = 0; i < sortedHand.length - 1; i++) {
  if (sameRank(sortedHand, i, 2) &&
  sortedHand[i].rank.index >
  last.highestCard.rank.index) {
  return sortedHand.sublist(i, i + 2);
  }
  }
  break;

  case HandType.triple:
  for (int i = 0; i < sortedHand.length - 2; i++) {
  if (sameRank(sortedHand, i, 3) &&
  sortedHand[i].rank.index >
  last.highestCard.rank.index) {
  return sortedHand.sublist(i, i + 3);
  }
  }
  break;

  case HandType.sequence:
  final seqs = generateSequences(lastPlayed.length);

  for (final seq in seqs) {
  final res = analyzeHand(seq);

  if (res.highestCard.value >
  last.highestCard.value) {
  return seq;
  }
  }
  break;

  default:
  break;
  }

  // ==================================
  // CHẶT HEO SMART
  // ==================================
  if (last.type == HandType.single &&
  last.highestCard.rank == CardRank.two) {
  final fk = findFourKind();

  if (fk.isNotEmpty) {
  if (shouldAggressive() ||
  hand.length <= 6 ||
  opponentCardsLeft <= 3) {
  return fk;
  }
  }
  }

  // ==================================
  // BAIT / FORCE PASS STRATEGY
  // ==================================
  if (style == BotStyle.aggressive &&
  last.type == HandType.single) {
  for (final card in sortedHand.reversed) {
  if (card.value > last.highestCard.value &&
  !isStrongCard(card)) {
  return [card];
  }
  }
  }

  return [];
  }
}
