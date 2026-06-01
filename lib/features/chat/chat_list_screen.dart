import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Stream<List<ChatModel>> _chatStream = const Stream.empty();
  final ChatService _chatService = ChatService();
  // Bộ nhớ đệm để lưu thông tin user, tránh load lại nhiều lần
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    // Khởi tạo stream một lần duy nhất tại đây
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _chatStream = _chatService.getChats(authState.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const Scaffold();
    final currentUser = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắn tin', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return const Center(child: Text('Chưa có cuộc trò chuyện nào.'));
          }

          // Sắp xếp tại local để không cần tạo Index trên Firebase
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

          return ListView.builder(
            // Thêm thuộc tính này để danh sách mượt hơn
            addAutomaticKeepAlives: true,
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUserId = chat.participants.firstWhere((id) => id != currentUser.uid);
              final isUnread = chat.unreadBy.contains(currentUser.uid);

              // Nếu đã có trong cache thì hiển thị luôn, không dùng FutureBuilder nữa
              if (_userCache.containsKey(otherUserId)) {
                final cachedData = _userCache[otherUserId]!;
                return _buildChatTile(chat, cachedData['name'] as String, cachedData['avatar'] as String?, otherUserId, isUnread);
              }

              // Nếu chưa có trong cache mới dùng FutureBuilder
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasData) {
                    final data = userSnapshot.data?.data() as Map<String, dynamic>?;
                    final name = data?['displayName'] ?? 'Người dùng';
                    final avatar = data?['avatarUrl'];
                    _userCache[otherUserId] = {'name': name, 'avatar': avatar}; // Lưu vào cache
                    return _buildChatTile(chat, name, avatar, otherUserId, isUnread);
                  }
                  return _buildChatTile(chat, '...', null, otherUserId, isUnread); // Placeholder khi đang load
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile(ChatModel chat, String name, String? avatarUrl, String otherUserId, bool isUnread) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[800],
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl)
            : const AssetImage('assets/images/logo.png') as ImageProvider,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          color: isUnread ? Colors.blueAccent : Colors.grey,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('HH:mm').format(chat.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: isUnread ? Colors.blueAccent : Colors.grey,
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isUnread)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
            ),
        ],
      ),
      onTap: () {
        // Đánh dấu đã đọc khi nhấn vào
        _chatService.markAsRead(chat.id, context.read<AuthBloc>().state is AuthAuthenticated 
          ? (context.read<AuthBloc>().state as AuthAuthenticated).user.uid 
          : '');
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: chat.id,
              otherUserName: name,
              otherUserId: otherUserId,
              otherUserAvatar: avatarUrl,
            ),
          ),
        );
      },
    );
  }
}
