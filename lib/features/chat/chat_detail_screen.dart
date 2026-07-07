import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phan_family/features/chat/bubble/valentin_bubble.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'components/attachment_sheet.dart';
import 'components/background_selector_sheet.dart';
import 'components/media_bubbles.dart';
import 'components/voice_recorder_widget.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;
  final String? otherUserAvatar;

  const ChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();

  // 1. Khai báo Stream cố định
  late Stream<List<MessageModel>> _messageStream;

  bool _isRecording = false;
  bool _showSendButton = false;

  @override
  void initState() {
    super.initState();
    // 2. Khởi tạo Stream một lần duy nhất
    _messageStream = _chatService.getMessages(widget.chatId);

    // Đánh dấu đã đọc ngay khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _chatService.markAsRead(widget.chatId, authState.user.uid);
      }
    });

    _messageController.addListener(() {
      if (mounted) {
        final isNotEmpty = _messageController.text.trim().isNotEmpty;
        if (isNotEmpty != _showSendButton) {
          setState(() {
            _showSendButton = isNotEmpty;
          });
        }
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _chatService.sendMessage(widget.chatId, authState.user.uid, text);
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ==========================================
  // MEDIA SENDING HELPERS
  // ==========================================
  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162435),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(width: 20),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _hideLoading() {
    Navigator.of(context).pop();
  }

  Future<void> _sendMediaMessage(File file, MessageType type) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final String typeStr = type == MessageType.image ? 'ảnh' : 'video';
    _showLoading('Đang tải lên $typeStr...');

    try {
      final String fileName = file.path.split('/').last;
      final String url = await _chatService.uploadMediaFile(
        chatId: widget.chatId,
        file: file,
        mediaType: type.toString().split('.').last,
        fileName: fileName,
      );

      await _chatService.sendMessage(
        widget.chatId,
        authState.user.uid,
        url,
        type: type,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi tệp: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      _hideLoading();
    }
  }

  Future<void> _uploadBackground(File file) async {
    _showLoading('Đang tải ảnh nền lên...');
    try {
      final String fileName =
          'bg_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final String url = await _chatService.uploadMediaFile(
        chatId: widget.chatId,
        file: file,
        mediaType: 'image',
        fileName: fileName,
      );
      await _chatService.updateChatTheme(widget.chatId, backgroundImage: url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải ảnh nền: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      _hideLoading();
    }
  }

  Future<void> _sendVoiceMessage(File file, int duration) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    _showLoading('Đang gửi tin nhắn thoại...');

    try {
      final String fileName = file.path.split('/').last;
      final String url = await _chatService.uploadMediaFile(
        chatId: widget.chatId,
        file: file,
        mediaType: 'audio',
        fileName: fileName,
      );

      await _chatService.sendMessage(
        widget.chatId,
        authState.user.uid,
        url,
        type: MessageType.audio,
        duration: duration,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi tin nhắn thoại: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isRecording = false;
      });
      _hideLoading();
    }
  }

  Future<void> _sendGifMessage(String gifUrl) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      await _chatService.sendMessage(
        widget.chatId,
        authState.user.uid,
        gifUrl,
        type: MessageType.gif,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi GIF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentSheet(
        onMediaSelected: (file, type) => _sendMediaMessage(file, type),
        onGifSelected: (gifUrl) => _sendGifMessage(gifUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng context.select để tránh rebuild toàn bộ nếu các state khác của Auth thay đổi
    final currentUserId = context.select((AuthBloc bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated ? state.user.uid : null;
    });

    if (currentUserId == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        // title: Row(
        //   children: [
        //     CircleAvatar(
        //       radius: 16,
        //       backgroundColor: Colors.grey[800],
        //       backgroundImage: widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty
        //           ? CachedNetworkImageProvider(widget.otherUserAvatar!)
        //           : const AssetImage('assets/images/logo.png') as ImageProvider,
        //     ),
        //     const SizedBox(width: 8),
        //     Text(widget.otherUserName),
        //   ],
        // ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Text(widget.otherUserName, style: TextStyle(color: Colors.white),),
        centerTitle: false,
        actions: [
          _buildCallButton(isVideo: false),
          const SizedBox(width: 8),
          _buildCallButton(isVideo: true),
          const SizedBox(width: 8),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, snapshot) {
              String? currentBackground;
              String? currentBubbleStyle;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                currentBackground = data['backgroundImage'];
                currentBubbleStyle = data['bubbleStyle'];
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'bg') {
                    _showBackgroundSelector(currentBackground);
                  } else if (value == 'bubble') {
                    _showBubbleStyleSelector(currentBubbleStyle);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'bg',
                    child: Text('Sửa ảnh chung'),
                  ),
                  const PopupMenuItem(
                    value: 'bubble',
                    child: Text('Thay đổi kiểu bubble chat'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, chatSnapshot) {
          String? bgImage;
          String? bubbleStyle;
          if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
            final data = chatSnapshot.data!.data() as Map<String, dynamic>;
            bgImage = data['backgroundImage'];
            bubbleStyle = data['bubbleStyle'];
          }

          BoxDecoration? bgDecoration;
          if (bgImage != null) {
            if (bgImage.startsWith('http')) {
              bgDecoration = BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(bgImage),
                  fit: BoxFit.cover,
                ),
              );
            } else {
              // It's a preset color ID
              bgDecoration = BoxDecoration(color: _getPresetColor(bgImage));
            }
          }

          return Container(
            decoration: bgDecoration,
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: _messageStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Center(child: Text('Lỗi: ${snapshot.error}'));

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUserId;
                          return _buildMessageBubble(message, isMe, bubbleStyle);
                        },
                      );
                    },
                  ),
                ),
                _buildMessageInput(bgDecoration != null),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBackgroundSelector(String? currentBg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackgroundSelectorSheet(
        currentBackground: currentBg,
        onPresetSelected: (presetId) {
          _chatService.updateChatTheme(
            widget.chatId,
            backgroundImage: presetId,
          );
        },
        onImageSelected: (file) {
          _uploadBackground(file);
        },
      ),
    );
  }

  void _showBubbleStyleSelector(String? currentStyle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162435),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Mặc định', style: TextStyle(color: Colors.white)),
              trailing: (currentStyle == null || currentStyle == 'default') 
                  ? const Icon(Icons.check, color: Colors.blueAccent) 
                  : null,
              onTap: () {
                _chatService.updateChatTheme(widget.chatId, bubbleStyle: 'default');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Valentine', style: TextStyle(color: Colors.white)),
              trailing: currentStyle == 'valentine' 
                  ? const Icon(Icons.check, color: Colors.blueAccent) 
                  : null,
              onTap: () {
                _chatService.updateChatTheme(widget.chatId, bubbleStyle: 'valentine');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getPresetColor(String presetId) {
    switch (presetId) {
      case 'color_pink':
        return Colors.pink.shade50;
      case 'color_blue':
        return Colors.blue.shade50;
      case 'color_green':
        return Colors.green.shade50;
      case 'color_yellow':
        return Colors.yellow.shade50;
      case 'color_purple':
        return Colors.purple.shade50;
      default:
        return const Color(0xFF162435);
    }
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, String? bubbleStyle) {
    Widget contentWidget;
    bool isMedia = false;

    switch (message.type) {
      case MessageType.image:
        contentWidget = ImageBubble(message: message, isMe: isMe);
        isMedia = true;
        break;
      case MessageType.video:
        contentWidget = VideoBubble(message: message, isMe: isMe);
        isMedia = true;
        break;
      case MessageType.audio:
        contentWidget = AudioBubble(message: message, isMe: isMe);
        isMedia = true;
        break;
      case MessageType.gif:
        contentWidget = GifBubble(message: message, isMe: isMe);
        isMedia = true;
        break;
      case MessageType.text:
      case MessageType.call:
      default:
        contentWidget = Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        );
        isMedia = false;
        break;
    }

    if (bubbleStyle == 'valentine') {
      final bubble = ValentineBubble(
        isMe: isMe,
        contentWidget: contentWidget,
        isMedia: isMedia,
        message: message,
      );

      if (isMe) return bubble;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 26),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                  : const AssetImage('assets/images/logo.png') as ImageProvider,
            ),
          ),
          Expanded(child: bubble),
        ],
      );
    }

    // Default Bubble
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: isMedia
            ? (message.type == MessageType.audio ? EdgeInsets.zero : const EdgeInsets.all(2))
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: isMedia && message.type != MessageType.audio
            ? null
            : BoxDecoration(
                color: isMe ? Colors.blueAccent : Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            contentWidget,
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMedia && message.type != MessageType.audio ? 8.0 : 0.0,
              ),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool hasBackground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: hasBackground
            ? Colors.black.withOpacity(0.5)
            : Theme.of(context).scaffoldBackgroundColor,
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: _isRecording
            ? VoiceRecorderWidget(
                onStopAndSend: _sendVoiceMessage,
                onCancel: () => setState(() => _isRecording = false),
              )
            : Row(
                children: [
                  // Attachment + Button
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    onPressed: _showAttachmentSheet,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(25)),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dynamic Send / Mic Icon
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: _showSendButton
                        ? IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: _sendMessage,
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.mic_none_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _isRecording = true;
                              });
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCallButton({required bool isVideo}) {
    return ZegoSendCallInvitationButton(
      isVideoCall: isVideo,
      resourceID: "zego_uikit_call",
      icon: ButtonIcon(
        icon: Icon(isVideo ? Icons.videocam : Icons.phone),
      ),
      buttonSize: const Size(40, 40),
      iconSize: const Size(24, 24),
      invitees: [
        ZegoUIKitUser(id: widget.otherUserId, name: widget.otherUserName),
      ],
    );
  }
}
