import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/comment_model.dart';
import '../../services/feed_service.dart';
import 'comment_event.dart';
import 'comment_state.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final FeedService _feedService;
  StreamSubscription? _commentsSubscription;
  String? _currentPostId;

  CommentBloc({required FeedService feedService})
      : _feedService = feedService,
        super(CommentInitial()) {
    on<LoadComments>(_onLoadComments);
    on<CommentsUpdated>(_onCommentsUpdated);
    on<CommentsErrorEvent>(_onCommentsError);
    on<AddCommentEvent>(_onAddComment);
    // Đăng ký event trong Constructor:
    on<ReactCommentEvent>(_onReactComment);
  }

  void _onLoadComments(LoadComments event, Emitter<CommentState> emit) {
    if (_currentPostId != event.postId) {
      emit(CommentLoading());
      _currentPostId = event.postId;
      _commentsSubscription?.cancel();
      _commentsSubscription = _feedService.getComments(event.postId).listen(
        (comments) {
          if (!isClosed) {
            add(CommentsUpdated(comments));
          }
        },
        onError: (error) {
          if (!isClosed) {
            add(CommentsErrorEvent('Lỗi tải bình luận: $error'));
          }
        },
      );
    }
  }

  void _onCommentsUpdated(CommentsUpdated event, Emitter<CommentState> emit) {
    emit(CommentLoaded(event.comments));
  }

  void _onCommentsError(CommentsErrorEvent event, Emitter<CommentState> emit) {
    emit(CommentError(event.error));
  }

  Future<void> _onAddComment(AddCommentEvent event, Emitter<CommentState> emit) async {
    final currentState = state;
    List<CommentModel> currentComments = [];
    if (currentState is CommentLoaded) {
      currentComments = currentState.comments;
    }
    
    emit(CommentSubmitting(currentComments));

    try {
      final comment = CommentModel(
        id: '',
        userId: event.userId,
        authorName: event.authorName,
        authorAvatar: event.authorAvatar,
        content: event.content,
        timestamp: DateTime.now(),
        parentId: event.parentId,
      );

      await _feedService.addComment(event.postId, comment);
      // Khi thêm xong Firestore Stream tự động cập nhật về CommentLoaded
    } catch (e) {
      emit(CommentError('Không thể gửi bình luận: $e'));
      // Phục hồi lại state cũ
      emit(CommentLoaded(currentComments));
    }
  }

  Future<void> _onReactComment(ReactCommentEvent event, Emitter<CommentState> emit) async {
    try {
      await _feedService.reactComment(
        postId: event.postId,
        commentId: event.commentId,
        userId: event.userId,
        reactionType: event.reactionType,
      );
    } catch (e) {
      emit(CommentError('Lỗi tương tác bình luận: $e'));
    }
  }
  @override
  Future<void> close() {
    _commentsSubscription?.cancel();
    return super.close();
  }
}
