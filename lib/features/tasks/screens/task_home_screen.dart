import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_state.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';
import 'task_leaderboard_screen.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({Key? key}) : super(key: key);

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen> {
  String _currentFilter = 'all'; // 'all', 'my_tasks'


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Việc nhà'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskLeaderboardScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              // open notifications
            },
          )
        ],
      ),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          if (state is TaskLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TaskLoaded) {
            final authState = context.read<AuthBloc>().state;
            final currentUserId = authState is AuthAuthenticated ? authState.user.uid : '';

            var tasks = state.tasks;
            if (_currentFilter == 'my_tasks') {
              tasks = tasks.where((t) => t.assignedTo == currentUserId).toList();
            } else if (_currentFilter == 'overdue') {
              tasks = tasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(DateTime.now()) && t.status != 'completed').toList();
            }

            // Sort: Overdue first, then Urgent, then due date
            tasks.sort((a, b) {
              if (a.status == 'completed' && b.status != 'completed') return 1;
              if (a.status != 'completed' && b.status == 'completed') return -1;
              
              bool aOverdue = a.dueDate != null && a.dueDate!.isBefore(DateTime.now()) && a.status != 'completed';
              bool bOverdue = b.dueDate != null && b.dueDate!.isBefore(DateTime.now()) && b.status != 'completed';
              if (aOverdue && !bOverdue) return -1;
              if (!aOverdue && bOverdue) return 1;

              return b.createdAt.compareTo(a.createdAt);
            });

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, userSnapshot) {
                Map<String, String> userNames = {};
                if (userSnapshot.hasData) {
                  for (var doc in userSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    userNames[doc.id] = data['displayName'] ?? 'Người dùng';
                  }
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: _currentFilter == 'all',
                            onSelected: (val) => setState(() => _currentFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Việc của tôi'),
                            selected: _currentFilter == 'my_tasks',
                            onSelected: (val) => setState(() => _currentFilter = 'my_tasks'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Quá hạn'),
                            selected: _currentFilter == 'overdue',
                            onSelected: (val) => setState(() => _currentFilter = 'overdue'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: tasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🏡 Chưa có nhiệm vụ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  const Text('Hãy tạo nhiệm vụ đầu tiên\nđể cùng nhau chia sẻ công việc.', textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen()));
                                    },
                                    child: const Text('+ Tạo nhiệm vụ')
                                  )
                                ],
                              )
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: tasks.length,
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                final assignedName = userNames[task.assignedTo] ?? 'Chưa giao';
                                final isOverdue = task.dueDate != null && task.dueDate!.isBefore(DateTime.now()) && task.status != 'completed';
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: isOverdue ? RoundedRectangleBorder(
                                    side: const BorderSide(color: Colors.red, width: 1.5),
                                    borderRadius: BorderRadius.circular(15),
                                  ) : null,
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)));
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: task.status == 'completed' ? Colors.green.withOpacity(0.2) : (isOverdue ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
                                      child: Icon(
                                        task.status == 'completed' ? Icons.check_circle : (isOverdue ? Icons.warning_amber_rounded : Icons.pending_actions),
                                        color: task.status == 'completed' ? Colors.green : (isOverdue ? Colors.red : Colors.orange),
                                      ),
                                    ),
                                    title: Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, decoration: task.status == 'completed' ? TextDecoration.lineThrough : null)),
                                    subtitle: Text('${isOverdue ? '⚠️ Quá hạn' : (task.status == 'completed' ? 'Đã hoàn thành' : 'Đang làm')} • 👤 $assignedName', style: TextStyle(color: isOverdue ? Colors.red : null)),
                                    trailing: Text('+${task.points}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          } else if (state is TaskError) {
            return Center(child: Text('Lỗi: ${state.message}'));
          }
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks_fab',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen()));
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
