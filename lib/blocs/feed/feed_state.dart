import 'package:equatable/equatable.dart';
import '../../models/post_model.dart';

abstract class FeedState extends Equatable {
  const FeedState();
  
  @override
  List<Object?> get props => [];
}

class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  final List<PostModel> posts;

  const FeedLoaded({this.posts = const []});

  @override
  List<Object?> get props => [posts];
}

class FeedError extends FeedState {
  final String message;

  const FeedError(this.message);

  @override
  List<Object?> get props => [message];
}

// Trạng thái khi đang tạo bài viết mới (hiển thị loading indicator khi upload ảnh)
class PostCreating extends FeedState {}

class PostCreateSuccess extends FeedState {}

class PostCreateError extends FeedState {
  final String message;

  const PostCreateError(this.message);

  @override
  List<Object?> get props => [message];
}
