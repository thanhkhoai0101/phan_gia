import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/task_model.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');

  String _priority = 'medium';
  String _category = 'cleaning';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String? _assignedTo;
  String _repeatType = 'none';

  final Map<String, String> _categories = {
    'cleaning': '🧹 Dọn dẹp',
    'cooking': '🍳 Nấu ăn',
    'shopping': '🛒 Mua sắm',
    'plants': '🌱 Cây cối',
    'pets': '🐕 Thú cưng',
    'repair': '🔧 Sửa chữa',
    'study': '📚 Học tập',
    'vehicles': '🚗 Xe cộ',
    'finance': '💰 Tài chính',
    'other': '🏠 Khác',
  };

  final Map<String, String> _priorities = {
    'low': 'Thấp',
    'medium': 'Trung bình',
    'high': 'Cao',
    'urgent': 'Khẩn cấp',
  };

  final Map<String, String> _repeatTypes = {
    'none': 'Không lặp lại',
    'daily': 'Hàng ngày',
    'weekly': 'Hàng tuần',
    'monthly': 'Hàng tháng',
  };

  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên nhiệm vụ')));
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    DateTime? finalDueDate;
    if (_dueDate != null) {
      finalDueDate = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        _dueTime?.hour ?? 23,
        _dueTime?.minute ?? 59,
      );
    }

    final task = TaskModel(
      id: '',
      title: title,
      description: _descController.text.trim(),
      createdBy: authState.user.uid,
      assignedTo: _assignedTo ?? '',
      priority: _priority,
      category: _category,
      dueDate: finalDueDate,
      points: int.tryParse(_pointsController.text) ?? 0,
      isRecurring: _repeatType != 'none',
      repeatType: _repeatType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.read<TaskBloc>().add(AddTask(task));
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo nhiệm vụ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Tên nhiệm vụ *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Mô tả (tuỳ chọn)', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final users = snapshot.data!.docs;
              
              final authState = context.read<AuthBloc>().state;
              final currentUserId = authState is AuthAuthenticated ? authState.user.uid : '';
              
              return DropdownButtonFormField<String>(
                value: _assignedTo,
                decoration: const InputDecoration(labelText: 'Giao cho', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Chưa giao cho ai')),
                  ...users.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['displayName'] ?? 'Người dùng'),
                    );
                  }).toList(),
                ],
                onChanged: (val) => setState(() => _assignedTo = val),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
            items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) => setState(() => _category = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(labelText: 'Độ ưu tiên', border: OutlineInputBorder()),
            items: _priorities.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) => setState(() => _priority = val!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pointsController,
            decoration: const InputDecoration(labelText: 'Điểm thưởng', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(_dueDate == null ? 'Chọn ngày' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickTime,
                  child: Text(_dueTime == null ? 'Chọn giờ' : '${_dueTime!.hour}:${_dueTime!.minute}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _repeatType,
            decoration: const InputDecoration(labelText: 'Lặp lại', border: OutlineInputBorder()),
            items: _repeatTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) => setState(() => _repeatType = val!),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _saveTask,
            child: const Text('Lưu nhiệm vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
