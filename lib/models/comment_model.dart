import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CommentModel extends Equatable {
  final String id;
  final String userId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime timestamp;

  const CommentModel({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timestamp,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorAvatar: data['authorAvatar'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [id, userId, authorName, authorAvatar, content, timestamp];
}
