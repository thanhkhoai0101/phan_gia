import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/feed/feed_bloc.dart';
import '../../blocs/feed/feed_event.dart';
import '../../blocs/feed/feed_state.dart';
import '../../models/user_model.dart';
import 'create_post_screen.dart';
import 'widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  final UserModel currentUser;

  const FeedScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    // Load feed when screen initializes
    context.read<FeedBloc>().add(LoadFeed());
  }

  void _navigateToCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<FeedBloc>(),
          child: CreatePostScreen(currentUser: widget.currentUser),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: RefreshIndicator(
        onRefresh: () async {
          context.read<FeedBloc>().add(LoadFeed());
        },
        child: CustomScrollView(
          slivers: [
            // Phân tạo bài viết (Write post area)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.currentUser.avatarUrl != null &&
                              widget.currentUser.avatarUrl!.isNotEmpty
                          ? NetworkImage(widget.currentUser.avatarUrl!)
                          : null,
                      child: widget.currentUser.avatarUrl == null ||
                              widget.currentUser.avatarUrl!.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToCreatePost,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1), // Background với opacity 10%
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.grey.shade400, // Màu viền
                              width: 1.0, // Độ dày của viền
                            ),
                          ),
                          child: Text(
                            '${widget.currentUser.displayName} ơi, bạn đang nghĩ gì?',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Danh sách bài viết
            BlocBuilder<FeedBloc, FeedState>(
              builder: (context, state) {
                if (state is FeedLoading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (state is FeedError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(state.message, style: const TextStyle(color: Colors.red)),
                    ),
                  );
                } else if (state is FeedLoaded) {
                  if (state.posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text('Chưa có bài viết nào.')),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = state.posts[index];
                        return PostCard(
                          post: post,
                          currentUser: widget.currentUser,
                          onReact: (reactionType) {
                            context.read<FeedBloc>().add(
                              ToggleReactionPost(
                                postId: post.id,
                                userId: widget.currentUser.uid,
                                reactionType: reactionType,
                              ),
                            );
                          },
                          onDelete: () {
                            context.read<FeedBloc>().add(DeletePost(post.id));
                          },
                        );
                      },
                      childCount: state.posts.length,
                    ),
                  );
                }
                
                return const SliverFillRemaining(
                  child: Center(child: Text('Đang tải...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
