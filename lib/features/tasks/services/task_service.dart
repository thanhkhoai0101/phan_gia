import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../../../services/notification_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _tasksCollection => _firestore.collection('tasks');

  Stream<List<TaskModel>> getTasks() {
    return _tasksCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> createTask(TaskModel task) async {
    await _tasksCollection.add(task.toMap());
    if (task.assignedTo.isNotEmpty && task.assignedTo != task.createdBy) {
      _sendTaskNotification(task.assignedTo, 'Nhiệm vụ mới', 'Bạn vừa được giao nhiệm vụ: ${task.title}');
    }
  }

  Future<void> _sendTaskNotification(String userId, String title, String body) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() as Map<String, dynamic>?;
      final fcmToken = data?['fcmToken'];
      if (fcmToken != null) {
        await NotificationService.sendPushNotification(fcmToken, title, body, type: 'task');
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> updateTask(TaskModel task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  Future<void> completeTask(TaskModel task, String completedByUid) async {
    WriteBatch batch = _firestore.batch();
    
    DocumentReference taskRef = _tasksCollection.doc(task.id);
    batch.update(taskRef, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'completedBy': completedByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    DocumentReference userRef = _firestore.collection('users').doc(completedByUid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final userName = userData?['displayName'] ?? 'Một thành viên';

    if (task.points > 0) {
      batch.update(userRef, {
        'balance': FieldValue.increment(task.points)
      });
    }

    if (task.isRecurring && task.repeatType != 'none') {
      DateTime nextDueDate = task.dueDate ?? DateTime.now();
      if (task.repeatType == 'daily') {
        nextDueDate = nextDueDate.add(const Duration(days: 1));
      } else if (task.repeatType == 'weekly') {
        nextDueDate = nextDueDate.add(const Duration(days: 7));
      } else if (task.repeatType == 'monthly') {
        nextDueDate = DateTime(nextDueDate.year, nextDueDate.month + 1, nextDueDate.day, nextDueDate.hour, nextDueDate.minute);
      }

      final nextTask = task.copyWith(
        id: '', // Will not be saved in map anyway since id is doc ID
        status: 'todo',
        dueDate: nextDueDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: null,
        completedBy: null,
      );
      batch.set(_tasksCollection.doc(), nextTask.toMap());
    }

    await batch.commit();

    if (task.createdBy.isNotEmpty && task.createdBy != completedByUid) {
      _sendTaskNotification(task.createdBy, 'Hoàn thành nhiệm vụ', '$userName đã hoàn thành: ${task.title}');
    }
  }
}
