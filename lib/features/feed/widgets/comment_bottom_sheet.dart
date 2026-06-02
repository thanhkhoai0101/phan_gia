import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phan_family/features/feed/widgets/reaction_popup.dart';
import '../../../blocs/comment/comment_bloc.dart';
import '../../../blocs/comment/comment_event.dart';
import '../../../blocs/comment/comment_state.dart';
import '../../../models/user_model.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final UserModel currentUser;

  const CommentBottomSheet({
    Key? key,
    required this.postId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _popupCommentId;

  // Lưu trữ bình luận đang được chọn để trả lời (null nghĩa là đang bình luận bài viết)
  dynamic _replyingToComment;

  @override
  void initState() {
    super.initState();
    context.read<CommentBloc>().add(LoadComments(widget.postId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    context.read<CommentBloc>().add(
      AddCommentEvent(
        postId: widget.postId,
        userId: widget.currentUser.uid,
        authorName: widget.currentUser.displayName,
        authorAvatar: widget.currentUser.avatarUrl ?? '',
        content: text,
        // TRUYỀN THÊM parentId: Nếu đang reply thì truyền id của comment cha, không thì null
        parentId: _replyingToComment?.id,
      ),
    );

    _commentController.clear();
    setState(() {
      _replyingToComment = null; // Gửi xong thì xóa trạng thái reply
    });
    FocusScope.of(context).unfocus();
  }

  void _startReply(dynamic comment) {
    setState(() {
      _replyingToComment = comment;
    });
    // Tự động focus vào ô nhập liệu và hiện bàn phím
    _commentFocusNode.requestFocus();
    // Gợi ý tag tên người đó vào ô nhập cho giống FB (tùy chọn)
    _commentController.text = '@${comment.authorName} ';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: keyboardSpace),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar trang trí
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Bình luận',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),

          // ─── DANH SÁCH BÌNH LUẬN ─────────────────────────────────
          Expanded(
            child: BlocBuilder<CommentBloc, CommentState>(
              builder: (context, state) {
                if (state is CommentLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is CommentError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
                }

                List comments = [];
                if (state is CommentLoaded) {
                  comments = state.comments;
                } else if (state is CommentSubmitting) {
                  comments = state.currentComments;
                }

                if (comments.isEmpty) {
                  return const Center(child: Text('Chưa có bình luận nào. Hãy là người đầu tiên!'));
                }

                // Tách biệt bình luận gốc (gốc) và bình luận con (replies)
                final rootComments = comments.where((c) => c.parentId == null || c.parentId.isEmpty).toList();

                return ListView.builder(
                  itemCount: rootComments.length,
                  itemBuilder: (context, index) {
                    final comment = rootComments[index];

                    // Lấy ra các câu trả lời thuộc bình luận này
                    final replies = comments.where((c) => c.parentId == comment.id).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bình luận gốc (Cha)
                        _buildCommentItem(comment, isReply: false),

                        // Danh sách bình luận con (Con) thụt lề vào trong
                        if (replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 46.0),
                            child: Column(
                              children: replies.map((reply) => _buildCommentItem(reply, isReply: true)).toList(),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ─── THANH NHẬP LIỆU & BANNER REPLY ───────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner hiển thị trạng thái "Đang trả lời..."
                if (_replyingToComment != null)
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Đang trả lời ${_replyingToComment.authorName}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _replyingToComment = null),
                          child: const Icon(Icons.close, size: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                // Ô nhập Text chính
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          decoration: InputDecoration(
                            hintText: _replyingToComment != null ? 'Trả lời bình luận...' : 'Viết bình luận...',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BlocBuilder<CommentBloc, CommentState>(
                        builder: (context, state) {
                          final isSubmitting = state is CommentSubmitting;
                          return IconButton(
                            icon: isSubmitting
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send, color: Colors.blue),
                            onPressed: isSubmitting ? null : _submitComment,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget con để tái sử dụng cho cả Comment gốc và Reply
  // Widget _buildCommentItem(dynamic comment, {required bool isReply}) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         CircleAvatar(
  //           radius: isReply ? 14 : 18, // Bình luận con avatar nhỏ hơn xíu
  //           backgroundImage: comment.authorAvatar.isNotEmpty ? NetworkImage(comment.authorAvatar) : null,
  //           child: comment.authorAvatar.isEmpty ? Icon(Icons.person, size: isReply ? 16 : 20) : null,
  //         ),
  //         const SizedBox(width: 10),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.all(10),
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey.shade100,
  //                   borderRadius: BorderRadius.circular(16),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       comment.authorName,
  //                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
  //                     ),
  //                     const SizedBox(height: 4),
  //                     Text(comment.content, style: const TextStyle(fontSize: 14)),
  //                   ],
  //                 ),
  //               ),
  //               // Hàng tương tác dưới khung chat (Thời gian + Nút trả lời)
  //               Padding(
  //                 padding: const EdgeInsets.only(left: 10, top: 4),
  //                 child: Row(
  //                   children: [
  //                     Text(
  //                       _formatTimestamp(comment.timestamp),
  //                       style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
  //                     ),
  //                     const SizedBox(width: 16),
  //                     // Không cho phép bấm "Trả lời" lồng nhau quá nhiều cấp (Chỉ cho phép Cha -> Con)
  //                     if (!isReply)
  //                       GestureDetector(
  //                         onTap: () => _startReply(comment),
  //                         child: Text(
  //                           'Trả lời',
  //                           style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12),
  //                         ),
  //                       ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

// Định nghĩa biến này ở đầu file state nhé:
  Widget _buildCommentItem(dynamic comment, {required bool isReply}) {
    // Lấy ra cảm xúc hiện tại của user trên comment này
    final myReaction = comment.reactions[widget.currentUser.uid];
    final hasReaction = myReaction != null;

    // Tận dụng hoàn toàn ReactionConfig của ông để lấy Icon, Label, Color
    final reactionIcon = hasReaction
        ? Text(ReactionConfig.emoji(myReaction), style: const TextStyle(fontSize: 14))
        : null;
    final reactionLabel = hasReaction ? ReactionConfig.label(myReaction) : 'Thích';
    final reactionColor = hasReaction ? ReactionConfig.color(myReaction) : Colors.grey.shade700;

    return Stack(
      clipBehavior: Clip.none, // Để popup thoải mái bay ra ngoài khung
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundImage: comment.authorAvatar.isNotEmpty ? NetworkImage(comment.authorAvatar) : null,
                child: comment.authorAvatar.isEmpty ? Icon(Icons.person, size: isReply ? 16 : 20) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Khung nội dung bình luận ───
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.authorName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(comment.content, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),

                        // Hiển thị tổng số cảm xúc ở góc dưới khung chat (Tận dụng ReactionConfig)
                        if (comment.reactions.isNotEmpty)
                          Positioned(
                            bottom: -6,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Lấy icon cảm xúc đầu tiên làm đại diện
                                  Text(ReactionConfig.emoji(comment.reactions.values.first), style: const TextStyle(fontSize: 11)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${comment.reactions.length}',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    // ─── Hàng nút bấm tương tác (Thời gian, Thích, Trả lời) ───
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 4),
                      child: Row(
                        children: [
                          Text(
                            _formatTimestamp(comment.timestamp),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(width: 16),

                          // NÚT THÍCH (Nhấn thường = Like, Nhấn giữ = Hiện Popup Biểu cảm)
                          GestureDetector(
                            onTap: () {
                              // Nhấn thường: Nếu có cảm xúc rồi thì hủy, chưa có thì mặc định gán 'like'
                              context.read<CommentBloc>().add(
                                ReactCommentEvent(
                                  postId: widget.postId,
                                  commentId: comment.id,
                                  userId: widget.currentUser.uid,
                                  reactionType: hasReaction ? null : 'like',
                                ),
                              );
                            },
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              setState(() => _popupCommentId = comment.id); // Kích hoạt mở popup tại dòng comment này
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (reactionIcon != null) ...[
                                  reactionIcon,
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  reactionLabel,
                                  style: TextStyle(color: reactionColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          if (!isReply)
                            GestureDetector(
                              onTap: () => _startReply(comment),
                              child: Text(
                                'Trả lời',
                                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lớp che để chạm ra ngoài là đóng popup cảm xúc của bình luận
        if (_popupCommentId == comment.id)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _popupCommentId = null),
              child: Container(color: Colors.transparent),
            ),
          ),

        // ─── HIỂN THỊ REACTION POPUP CỦA ÔNG TẠI ĐÂY ───
        if (_popupCommentId == comment.id)
          Positioned(
            bottom: 30, // Đẩy popup nổi lên trên nút Thích một khoảng vừa vặn
            left: isReply ? 50 : 20, // Căn chỉnh lề trái tùy thuộc vào comment gốc hay reply con
            child: ReactionPopup(
              onReactionSelected: (type) {
                context.read<CommentBloc>().add(
                  ReactCommentEvent(
                    postId: widget.postId,
                    commentId: comment.id,
                    userId: widget.currentUser.uid,
                    reactionType: type,
                  ),
                );
                setState(() => _popupCommentId = null); // Chọn xong thì ẩn popup đi
              },
              onClose: () => setState(() => _popupCommentId = null),
            ),
          ),
      ],
    );
  }
}
