import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/task_model.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';

class TaskDetailScreen extends StatelessWidget {
  final TaskModel task;
  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.uid : '';
    final canDelete = task.createdBy == currentUserId;
    final canComplete = task.assignedTo == currentUserId || task.assignedTo.isEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết nhiệm vụ'),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context.read<TaskBloc>().add(DeleteTask(task.id));
                Navigator.pop(context);
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Danh mục: ${task.category}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Độ ưu tiên: ${task.priority}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Điểm thưởng: +${task.points}', style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Hạn chót: ${task.dueDate != null ? "${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year} ${task.dueDate!.hour}:${task.dueDate!.minute}" : "Không có"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Trạng thái: ${task.status == 'completed' ? 'Đã hoàn thành' : 'Đang làm'}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Mô tả:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(task.description.isEmpty ? 'Không có mô tả' : task.description, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            if (task.status != 'completed' && canComplete)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    context.read<TaskBloc>().add(CompleteTask(task, currentUserId));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã hoàn thành! +${task.points} điểm 🎉')));
                    Navigator.pop(context);
                  },
                  child: const Text('Hoàn thành nhiệm vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
          ],
        ),
      ),
    );
  }
}
