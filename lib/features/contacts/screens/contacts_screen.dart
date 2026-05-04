import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/screens/chat_detail_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const Scaffold();
    final currentUser = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên gia đình', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final users = snapshot.data!.docs.where((doc) => doc.id != currentUser.uid).toList();
          
          if (users.isEmpty) return const Center(child: Text('Chưa có thành viên nào khác.'));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userName = userData['displayName'] ?? 'Người dùng';
              final userId = users[index].id;

              return ListTile(
                leading: IconButton(
                  onPressed: () {},
                  icon: const CircleAvatar(child: Icon(Icons.person)),),
                title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Đang hoạt động'),
                trailing:  const Icon(Icons.chat_outlined, color: Colors.blue),
                onTap: ()async {
                  final chatId = await ChatService().getOrCreateChat(currentUser.uid, userId);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          chatId: chatId,
                          otherUserName: userName,
                          otherUserId: userId,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
