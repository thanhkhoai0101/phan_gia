enum CardSuit { spade, club, diamond, heart }

enum CardRank {
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
  two
}

class CardModel {
  final CardRank rank;
  final CardSuit suit;

  CardModel({required this.rank, required this.suit});

  // Unique value for sorting and comparison
  // 3 spade = 0, ..., 2 heart = 51
  int get value => rank.index * 4 + suit.index;

  String get name {
    String r = '';
    switch (rank) {
      case CardRank.three: r = '3'; break;
      case CardRank.four: r = '4'; break;
      case CardRank.five: r = '5'; break;
      case CardRank.six: r = '6'; break;
      case CardRank.seven: r = '7'; break;
      case CardRank.eight: r = '8'; break;
      case CardRank.nine: r = '9'; break;
      case CardRank.ten: r = '10'; break;
      case CardRank.jack: r = 'J'; break;
      case CardRank.queen: r = 'Q'; break;
      case CardRank.king: r = 'K'; break;
      case CardRank.ace: r = 'A'; break;
      case CardRank.two: r = '2'; break;
    }
    String s = '';
    switch (suit) {
      case CardSuit.spade: s = '♠️'; break;
      case CardSuit.club: s = '♣️'; break;
      case CardSuit.diamond: s = '♦️'; break;
      case CardSuit.heart: s = '♥️'; break;
    }
    return '$r$s';
  }

  Map<String, dynamic> toMap() {
    return {
      'rank': rank.index,
      'suit': suit.index,
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      rank: CardRank.values[map['rank']],
      suit: CardSuit.values[map['suit']],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CardModel &&
              runtimeType == other.runtimeType &&
              rank == other.rank &&
              suit == other.suit;

  @override
  int get hashCode => rank.hashCode ^ suit.hashCode;
}
