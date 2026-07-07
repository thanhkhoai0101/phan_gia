import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('🏆 Bảng Xếp Hạng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A3E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('banGaHighScore', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi tải dữ liệu: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có dữ liệu người chơi.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('banGaHighScore') && data['banGaHighScore'] > 0;
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có dữ liệu người chơi.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['displayName'] ?? 'Người chơi ẩn danh';
              final score = data['banGaHighScore'] ?? 0;
              final avatar = data['avatarUrl'];

              final isTop3 = index < 3;
              Color tileColor;
              if (index == 0) {
                tileColor = Colors.amber.withValues(alpha: 0.2);
              } else if (index == 1) {
                tileColor = Colors.grey.shade300.withValues(alpha: 0.2);
              } else if (index == 2) {
                tileColor = Colors.brown.shade300.withValues(alpha: 0.2);
              } else {
                tileColor = const Color(0xFF1A1A3E);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isTop3 ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    backgroundColor: Colors.deepPurple,
                    child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(
                            color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
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
