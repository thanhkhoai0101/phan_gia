import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../models/card_model.dart';
import '../../models/room_model.dart';

class TienLenRoomState extends Equatable {
  final RoomModel? room;
  final Set<CardModel> selectedCards;
  final int secondsLeft;
  final String? effectText;
  final Color? effectColor;
  final String? soundToPlay; // One-time sound trigger
  final bool isKicked;

  const TienLenRoomState({
    this.room,
    this.selectedCards = const {},
    this.secondsLeft = 15,
    this.effectText,
    this.effectColor,
    this.soundToPlay,
    this.isKicked = false,
  });

  TienLenRoomState copyWith({
    RoomModel? room,
    Set<CardModel>? selectedCards,
    int? secondsLeft,
    String? effectText,
    Color? effectColor,
    String? soundToPlay,
    bool? isKicked,
  }) {
    return TienLenRoomState(
      room: room ?? this.room,
      selectedCards: selectedCards ?? this.selectedCards,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      effectText: effectText, // Allow null to reset
      effectColor: effectColor ?? this.effectColor,
      soundToPlay: soundToPlay, // Usually nullified after playing
      isKicked: isKicked ?? this.isKicked,
    );
  }

  @override
  List<Object?> get props => [room, selectedCards, secondsLeft, effectText, effectColor, soundToPlay, isKicked];
}
