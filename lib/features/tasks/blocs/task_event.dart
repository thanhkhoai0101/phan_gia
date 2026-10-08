import 'package:equatable/equatable.dart';
import '../models/task_model.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {}

class TasksUpdated extends TaskEvent {
  final List<TaskModel> tasks;
  const TasksUpdated(this.tasks);

  @override
  List<Object> get props => [tasks];
}

class AddTask extends TaskEvent {
  final TaskModel task;
  const AddTask(this.task);

  @override
  List<Object> get props => [task];
}

class UpdateTask extends TaskEvent {
  final TaskModel task;
  const UpdateTask(this.task);

  @override
  List<Object> get props => [task];
}

class DeleteTask extends TaskEvent {
  final String taskId;
  const DeleteTask(this.taskId);

  @override
  List<Object> get props => [taskId];
}

class CompleteTask extends TaskEvent {
  final TaskModel task;
  final String completedByUid;
  const CompleteTask(this.task, this.completedByUid);

  @override
  List<Object> get props => [task, completedByUid];
}
