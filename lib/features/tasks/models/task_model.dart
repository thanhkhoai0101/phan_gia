import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final String assignedTo;
  final String status; // 'todo', 'in_progress', 'completed', 'cancelled'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String category;
  final DateTime? dueDate;
  final int points;
  final List<int> reminders;
  final bool isRecurring;
  final String repeatType; // 'none', 'daily', 'weekly', 'monthly'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completedBy;

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdBy,
    this.assignedTo = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.category = 'other',
    this.dueDate,
    this.points = 0,
    this.reminders = const [],
    this.isRecurring = false,
    this.repeatType = 'none',
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.completedBy,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    String? assignedTo,
    String? status,
    String? priority,
    String? category,
    DateTime? dueDate,
    int? points,
    List<int>? reminders,
    bool? isRecurring,
    String? repeatType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completedBy,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      points: points ?? this.points,
      reminders: reminders ?? this.reminders,
      isRecurring: isRecurring ?? this.isRecurring,
      repeatType: repeatType ?? this.repeatType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
      'status': status,
      'priority': priority,
      'category': category,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'points': points,
      'reminders': reminders,
      'isRecurring': isRecurring,
      'repeatType': repeatType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completedBy': completedBy,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskModel(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      assignedTo: map['assignedTo'] ?? '',
      status: map['status'] ?? 'todo',
      priority: map['priority'] ?? 'medium',
      category: map['category'] ?? 'other',
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
      points: map['points'] ?? 0,
      reminders: List<int>.from(map['reminders'] ?? []),
      isRecurring: map['isRecurring'] ?? false,
      repeatType: map['repeatType'] ?? 'none',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      startedAt: map['startedAt'] != null ? (map['startedAt'] as Timestamp).toDate() : null,
      completedAt: map['completedAt'] != null ? (map['completedAt'] as Timestamp).toDate() : null,
      completedBy: map['completedBy'],
    );
  }
}
