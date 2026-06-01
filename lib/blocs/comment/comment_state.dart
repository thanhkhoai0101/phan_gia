import 'package:equatable/equatable.dart';
import '../../models/comment_model.dart';

abstract class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {}

class CommentLoading extends CommentState {}

class CommentLoaded extends CommentState {
  final List<CommentModel> comments;

  const CommentLoaded(this.comments);

  @override
  List<Object?> get props => [comments];
}

class CommentError extends CommentState {
  final String message;

  const CommentError(this.message);

  @override
  List<Object?> get props => [message];
}

// Trạng thái khi đang gửi comment
class CommentSubmitting extends CommentState {
  final List<CommentModel> currentComments;

  const CommentSubmitting(this.currentComments);

  @override
  List<Object?> get props => [currentComments];
}
