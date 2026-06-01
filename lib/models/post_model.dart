import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MediaType { none, image, video }

class PostModel extends Equatable {
  final String id;
  final String userId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final String? mediaUrl;
  final MediaType mediaType;
  final DateTime timestamp;
  final Map<String, String> reactions;
  final int commentCount;

  const PostModel({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    this.mediaUrl,
    this.mediaType = MediaType.none,
    required this.timestamp,
    this.reactions = const {},
    this.commentCount = 0,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    MediaType type = MediaType.none;
    if (data['mediaType'] == 'image') type = MediaType.image;
    if (data['mediaType'] == 'video') type = MediaType.video;

    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorAvatar: data['authorAvatar'] ?? '',
      content: data['content'] ?? '',
      mediaUrl: data['mediaUrl'],
      mediaType: type,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      commentCount: data['commentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': reactions,
      'commentCount': commentCount,
    };
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? authorName,
    String? authorAvatar,
    String? content,
    String? mediaUrl,
    MediaType? mediaType,
    DateTime? timestamp,
    Map<String, String>? reactions,
    int? commentCount,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      timestamp: timestamp ?? this.timestamp,
      reactions: reactions ?? this.reactions,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        authorName,
        authorAvatar,
        content,
        mediaUrl,
        mediaType,
        timestamp,
        reactions,
        commentCount,
      ];
}
