import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'task_event.dart';
import 'task_state.dart';
import '../services/task_service.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskService _taskService;
  StreamSubscription? _tasksSubscription;

  TaskBloc(this._taskService) : super(TaskLoading()) {
    on<LoadTasks>(_onLoadTasks);
    on<TasksUpdated>(_onTasksUpdated);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<CompleteTask>(_onCompleteTask);
  }

  void _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) {
    emit(TaskLoading());
    _tasksSubscription?.cancel();
    _tasksSubscription = _taskService.getTasks().listen(
      (tasks) => add(TasksUpdated(tasks)),
      onError: (error) => emit(TaskError(error.toString())),
    );
  }

  void _onTasksUpdated(TasksUpdated event, Emitter<TaskState> emit) {
    emit(TaskLoaded(event.tasks));
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    try {
      await _taskService.createTask(event.task);
    } catch (e) {
      // Handle error gracefully or emit error state if needed
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    try {
      await _taskService.updateTask(event.task);
    } catch (e) {
      // Handle error gracefully
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    try {
      await _taskService.deleteTask(event.taskId);
    } catch (e) {
      // Handle error gracefully
    }
  }

  Future<void> _onCompleteTask(CompleteTask event, Emitter<TaskState> emit) async {
    try {
      await _taskService.completeTask(event.task, event.completedByUid);
    } catch (e) {
      // Handle error gracefully
    }
  }

  @override
  Future<void> close() {
    _tasksSubscription?.cancel();
    return super.close();
  }
}
