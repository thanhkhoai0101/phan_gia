import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isGroup;
  final String? groupName;
  final String? groupIcon;

  final List<String> unreadBy;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isGroup,
    this.unreadBy = const [],
    this.groupName,
    this.groupIcon,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatModel(
      id: docId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null 
          ? (map['lastMessageTime'] as Timestamp).toDate() 
          : DateTime.now(),
      isGroup: map['isGroup'] ?? false,
      unreadBy: (map['unreadBy'] as List?)?.map((e) => e.toString()).toList() ?? [],
      groupName: map['groupName'],
      groupIcon: map['groupIcon'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isGroup': isGroup,
      'unreadBy': unreadBy,
      'groupName': groupName,
      'groupIcon': groupIcon,
    };
  }
}
