import 'package:equatable/equatable.dart';
import 'package:phan_family/models/comment_model.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object?> get props => [];
}

class LoadComments extends CommentEvent {
  final String postId;

  const LoadComments(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CommentsUpdated extends CommentEvent {
  final List<CommentModel> comments;

  const CommentsUpdated(this.comments);

  @override
  List<Object?> get props => [comments];
}

class CommentsErrorEvent extends CommentEvent {
  final String error;

  const CommentsErrorEvent(this.error);

  @override
  List<Object?> get props => [error];
}

class AddCommentEvent extends CommentEvent {
  final String postId;
  final String userId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final String parentId;

  const AddCommentEvent({
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.parentId,
  });

  @override
  List<Object?> get props => [postId, userId, authorName, authorAvatar, content, parentId];
}

class ReactCommentEvent extends CommentEvent {
  final String postId;
  final String commentId;
  final String userId;
  final String? reactionType; // Nếu null nghĩa là hủy bỏ bày tỏ cảm xúc

  const ReactCommentEvent({
    required this.postId,
    required this.commentId,
    required this.userId,
    this.reactionType,
  });
}
