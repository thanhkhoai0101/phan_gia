import 'dart:math';
import '../models/card_model.dart';

class GameEngine {
  static List<CardModel> createFullDeck() {
    List<CardModel> deck = [];
    for (var rank in CardRank.values) {
      for (var suit in CardSuit.values) {
        deck.add(CardModel(rank: rank, suit: suit));
      }
    }
    return deck;
  }

  static Map<String, List<CardModel>> dealCards(List<String> playerIds) {
    List<CardModel> deck = createFullDeck();
    deck.shuffle(Random());

    Map<String, List<CardModel>> hands = {};
    for (int i = 0; i < playerIds.length; i++) {
      // Deal 13 cards each
      List<CardModel> hand = deck.sublist(i * 13, (i + 1) * 13);
      // Sort hand by value
      hand.sort((a, b) => a.value.compareTo(b.value));
      hands[playerIds[i]] = hand;
    }
    return hands;
  }

  static String findFirstPlayer(Map<String, List<CardModel>> hands) {
    // In Tien Len, player with 3 of Spades goes first
    CardModel threeSpades = CardModel(rank: CardRank.three, suit: CardSuit.spade);
    for (var entry in hands.entries) {
      if (entry.value.contains(threeSpades)) {
        return entry.key;
      }
    }
    // Fallback
    return hands.keys.first;
  }
}
