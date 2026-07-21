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
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
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

  void _showCreateGroupDialog(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final currentUser = authState.user;

    String groupName = "";
    List<String> selectedMemberIds = [];
    bool addBot = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF162435),
              title: const Text("Tạo nhóm chat mới", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Tên nhóm",
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                        onChanged: (val) => groupName = val.trim(),
                      ),
                      const SizedBox(height: 20),
                      CheckboxListTile(
                        title: const Text("Thêm Bot Nối Từ 🤖", style: TextStyle(color: Colors.white)),
                        subtitle: const Text("Chơi game nối từ trong chat bằng cách gõ !noitu", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        value: addBot,
                        activeColor: Colors.blueAccent,
                        checkColor: Colors.white,
                        onChanged: (val) {
                          setDialogState(() {
                            addBot = val ?? false;
                          });
                        },
                      ),
                      const Divider(color: Colors.white24),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("Chọn thành viên:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('users').get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final members = userSnapshot.data!.docs
                              .where((doc) => doc.id != currentUser.uid)
                              .toList();
                          if (members.isEmpty) {
                            return const Text("Không tìm thấy thành viên khác", style: TextStyle(color: Colors.grey));
                          }
                          return Column(
                            children: members.map((doc) {
                              final userData = doc.data() as Map<String, dynamic>;
                              final name = userData['displayName'] ?? 'Người dùng';
                              final uid = doc.id;
                              final isSelected = selectedMemberIds.contains(uid);
                              return CheckboxListTile(
                                title: Text(name, style: const TextStyle(color: Colors.white)),
                                value: isSelected,
                                activeColor: Colors.blueAccent,
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedMemberIds.add(uid);
                                    } else {
                                      selectedMemberIds.remove(uid);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    if (groupName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Vui lòng nhập tên nhóm!"), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    if (selectedMemberIds.isEmpty && !addBot) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Vui lòng chọn ít nhất 1 thành viên hoặc thêm Bot!"), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }

                    // Gọi dịch vụ tạo nhóm
                    final chatId = await _chatService.createGroupChat(
                      creatorId: currentUser.uid,
                      groupName: groupName,
                      memberIds: selectedMemberIds,
                      addBot: addBot,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Đóng Dialog
                      // Chuyển trực tiếp tới phòng chat nhóm mới
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: chatId,
                            otherUserName: groupName,
                            otherUserId: chatId, // dùng tạm chatId cho group
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text("Tạo", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
