import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../models/post_model.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeed extends FeedEvent {}

class UpdateFeed extends FeedEvent {
  final List<PostModel> posts;

  const UpdateFeed(this.posts);

  @override
  List<Object?> get props => [posts];
}

class AddPost extends FeedEvent {
  final String userId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final File? mediaFile;
  final MediaType mediaType;

  const AddPost({
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    this.mediaFile,
    this.mediaType = MediaType.none,
  });

  @override
  List<Object?> get props => [userId, authorName, authorAvatar, content, mediaFile, mediaType];
}

class ToggleReactionPost extends FeedEvent {
  final String postId;
  final String userId;
  final String? reactionType; // null = huỷ cảm xúc

  const ToggleReactionPost({required this.postId, required this.userId, this.reactionType});

  @override
  List<Object?> get props => [postId, userId, reactionType];
}

class DeletePost extends FeedEvent {
  final String postId;

  const DeletePost(this.postId);

  @override
  List<Object?> get props => [postId];
}
