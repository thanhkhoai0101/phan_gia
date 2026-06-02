import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'comment_bottom_sheet.dart';
import 'reaction_popup.dart';
import '../../../blocs/comment/comment_bloc.dart';
import '../../../services/feed_service.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final UserModel currentUser;
  final Function(String? reactionType) onReact;
  final VoidCallback onDelete;

  const PostCard({
    Key? key,
    required this.post,
    required this.currentUser,
    required this.onReact,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _showReactionPopup = false;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    if (widget.post.mediaType == MediaType.video && widget.post.mediaUrl != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl!))
        ..initialize().then((_) => setState(() {}));
    }
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
  }

  void _handleTapLike() {
    final myReaction = widget.post.reactions[widget.currentUser.uid];
    _likeAnimController.forward(from: 0);
    HapticFeedback.lightImpact();
    if (myReaction != null) {
      // Đã có cảm xúc → huỷ
      widget.onReact(null);
    } else {
      // Chưa có → mặc định Like
      widget.onReact('like');
    }
  }

  void _handleLongPressLike() {
    HapticFeedback.mediumImpact();
    setState(() => _showReactionPopup = true);
  }

  void _handleReactionSelected(String type) {
    setState(() => _showReactionPopup = false);
    _likeAnimController.forward(from: 0);
    widget.onReact(type);
  }

  /// Xây dựng hàng tóm tắt biểu cảm (emoji + count)
  Widget _buildReactionSummary() {
    final reactions = widget.post.reactions;
    if (reactions.isEmpty && widget.post.commentCount == 0) {
      return const SizedBox.shrink();
    }

    // Đếm từng loại reaction
    final Map<String, int> counts = {};
    for (final type in reactions.values) {
      counts[type] = (counts[type] ?? 0) + 1;
    }

    // Lấy top 3 reaction nhiều nhất
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topReactions = sorted.take(3).map((e) => e.key).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          // Emoji bubbles
          if (reactions.isNotEmpty) ...[
            ...topReactions.map((type) => Text(
                  ReactionConfig.emoji(type),
                  style: const TextStyle(fontSize: 16),
                )),
            const SizedBox(width: 4),
            Text(
              '${reactions.length}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
          const Spacer(),
          if (widget.post.commentCount > 0)
            Text(
              '${widget.post.commentCount} bình luận',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myReaction = widget.post.reactions[widget.currentUser.uid];
    final hasReaction = myReaction != null;
    final isOwner = widget.post.userId == widget.currentUser.uid;

    final reactionIcon = hasReaction
        ? Text(ReactionConfig.emoji(myReaction), style: const TextStyle(fontSize: 18))
        : const Icon(Icons.thumb_up_outlined, size: 20);
    final reactionLabel = hasReaction ? ReactionConfig.label(myReaction) : 'Thích';
    final reactionColor = hasReaction ? ReactionConfig.color(myReaction) : Colors.grey.shade700;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.post.authorAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(widget.post.authorAvatar)
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: widget.post.authorAvatar.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.post.authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_formatTimestamp(widget.post.timestamp),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(LucideIcons.trash2, color: Colors.red),
                                    title: const Text('Xoá bài viết',
                                        style: TextStyle(color: Colors.red)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      widget.onDelete();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // ─── Content ─────────────────────────────────
              if (widget.post.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Text(widget.post.content, style: const TextStyle(fontSize: 15)),
                ),

              const SizedBox(height: 8),

              // ─── Media ───────────────────────────────────
              if (widget.post.mediaType == MediaType.image && widget.post.mediaUrl != null)
                CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => const Icon(Icons.error),
                ),

              if (widget.post.mediaType == MediaType.video && _videoController != null)
                _videoController!.value.isInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          // Lớp che phía sau popup để đóng khi tap ngoài
                          if (_showReactionPopup)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => setState(() => _showReactionPopup = false),
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                          IconButton(
                            iconSize: 50,
                            icon: Icon(
                              _videoController!.value.isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            onPressed: () => setState(() {
                              _videoController!.value.isPlaying
                                  ? _videoController!.pause()
                                  : _videoController!.play();
                            }),
                          ),
                        ],
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator())),

              // ─── Reaction summary ─────────────────────────
              _buildReactionSummary(),

              const Divider(height: 1),

              // ─── Action buttons ───────────────────────────
              Row(
                children: [
                  // LIKE (nhấn thường / nhấn giữ)
                  Expanded(
                    child: GestureDetector(
                      onTap: _handleTapLike,
                      onLongPress: _handleLongPressLike,
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _likeScaleAnim,
                              child: reactionIcon,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              reactionLabel,
                              style: TextStyle(
                                  color: reactionColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // COMMENT
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _showReactionPopup = false);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => BlocProvider(
                            create: (_) => CommentBloc(feedService: FeedService()),
                            child: CommentBottomSheet(
                              postId: widget.post.id,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.grey.shade700, size: 20),
                            const SizedBox(width: 6),
                            Text('Bình luận',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // SHARE
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _showReactionPopup = false);
                        String shareText =
                            'Xem bài viết của ${widget.post.authorName} trên Phan Gia:\n${widget.post.content}';
                        if (widget.post.mediaUrl != null) {
                          shareText += '\n${widget.post.mediaUrl}';
                        }
                        Share.share(shareText);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_outlined,
                                color: Colors.grey.shade700, size: 20),
                            const SizedBox(width: 6),
                            Text('Chia sẻ',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── Reaction Popup (nổi phía trên nút Thích) ────
        if (_showReactionPopup)
          Positioned(
            bottom: 58,
            left: 8,
            child: GestureDetector(
              onTap: () {}, // Ngăn tap xuyên qua popup
              child: ReactionPopup(
                onReactionSelected: _handleReactionSelected,
                onClose: () => setState(() => _showReactionPopup = false),
              ),
            ),
          ),

      ],
    );
  }
}
