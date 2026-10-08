import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskLeaderboardScreen extends StatelessWidget {
  const TaskLeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Xếp Hạng'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('balance', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final users = snapshot.data!.docs;
          if (users.isEmpty) return const Center(child: Text('Chưa có thành viên nào.'));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final name = data['displayName'] ?? 'Người dùng';
              final points = data['balance'] ?? 0;
              final avatar = data['avatarUrl'];

              String rank = 'Thành viên mới';
              if (points > 1000) rank = '🌟 Siêu sao việc nhà';
              else if (points > 500) rank = '🔥 Chăm chỉ';
              else if (points > 100) rank = '👍 Tích cực';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    backgroundColor: Colors.orange.shade100,
                    child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, color: Colors.orange) : null,
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(rank, style: const TextStyle(color: Colors.grey)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                      Text('$points đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
