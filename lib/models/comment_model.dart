import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CommentModel extends Equatable {
  final String id;
  final String userId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime timestamp;
  final String? parentId;
  final Map<String, String>? reactions;

  const CommentModel({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timestamp,
    required this.parentId,
    this.reactions,
  });

  factory CommentModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return CommentModel(
      id: docId,
      userId: json['userId'] ?? '',
      authorName: json['authorName'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      content: json['content'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      parentId: json['parentId'],
      // Ép kiểu về Map<String, String>
      reactions: Map<String, String>.from(json['reactions'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': reactions,
      if (parentId != null) 'parentId': parentId,
    };
  }

  @override
  List<Object?> get props => [id, userId, authorName, authorAvatar, content, timestamp, reactions];
}
