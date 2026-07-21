import 'package:cloud_firestore/cloud_firestore.dart';

class DrawMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isSystemMsg;
  final bool isCorrectGuess;

  DrawMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isSystemMsg = false,
    this.isCorrectGuess = false,
  });

  factory DrawMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return DrawMessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isSystemMsg: map['isSystemMsg'] ?? false,
      isCorrectGuess: map['isCorrectGuess'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isSystemMsg': isSystemMsg,
      'isCorrectGuess': isCorrectGuess,
    };
  }
}
