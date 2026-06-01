import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/feed_service.dart';
import '../../models/post_model.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final FeedService _feedService;
  StreamSubscription? _feedSubscription;

  FeedBloc({required FeedService feedService})
      : _feedService = feedService,
        super(FeedLoading()) {
    on<LoadFeed>(_onLoadFeed);
    on<UpdateFeed>(_onUpdateFeed);
    on<AddPost>(_onAddPost);
    on<ToggleReactionPost>(_onToggleReactionPost);
    on<DeletePost>(_onDeletePost);
  }

  void _onLoadFeed(LoadFeed event, Emitter<FeedState> emit) {
    emit(FeedLoading());
    _feedSubscription?.cancel();
    _feedSubscription = _feedService.getPosts().listen(
      (posts) {
        add(UpdateFeed(posts));
      },
      onError: (error) {
        emit(FeedError('Lỗi tải bảng tin: $error'));
      },
    );
  }

  void _onUpdateFeed(UpdateFeed event, Emitter<FeedState> emit) {
    emit(FeedLoaded(posts: event.posts));
  }

  Future<void> _onAddPost(AddPost event, Emitter<FeedState> emit) async {
    final currentState = state;
    emit(PostCreating());
    
    try {
      String? mediaUrl;
      
      // Nếu có đính kèm file, upload file trước
      if (event.mediaFile != null) {
        mediaUrl = await _feedService.uploadMedia(event.mediaFile!, event.userId);
        if (mediaUrl == null) {
          emit(const PostCreateError('Không thể tải lên ảnh/video.'));
          return;
        }
      }

      // Tạo đối tượng post
      final post = PostModel(
        id: '', // Firestore sẽ tự generate
        userId: event.userId,
        authorName: event.authorName,
        authorAvatar: event.authorAvatar,
        content: event.content,
        mediaUrl: mediaUrl,
        mediaType: event.mediaType,
        timestamp: DateTime.now(),
      );

      // Lưu vào Firestore
      await _feedService.createPost(post);
      
      emit(PostCreateSuccess());
    } catch (e) {
      emit(PostCreateError('Lỗi tạo bài viết: $e'));
    }

    // Sau khi đăng bài (thành công hoặc thất bại), quay về trạng thái loaded
    if (currentState is FeedLoaded) {
      emit(currentState);
    } else {
      add(LoadFeed());
    }
  }

  Future<void> _onToggleReactionPost(ToggleReactionPost event, Emitter<FeedState> emit) async {
    await _feedService.toggleReaction(event.postId, event.userId, event.reactionType);
  }

  Future<void> _onDeletePost(DeletePost event, Emitter<FeedState> emit) async {
    await _feedService.deletePost(event.postId);
  }

  @override
  Future<void> close() {
    _feedSubscription?.cancel();
    return super.close();
  }
}
