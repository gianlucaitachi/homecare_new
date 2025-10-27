import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../Models/task.dart';
import '../Models/task_list_response.dart';
import '../Models/task_response.dart';
import '../Services/task_service.dart';
import '../Services/task_storage.dart';

class TaskRepository extends ChangeNotifier {
  TaskRepository({TaskService? taskService, TaskStorage? taskStorage})
      : _taskService = taskService ?? TaskService(),
        _taskStorage = taskStorage ?? TaskStorage.instance {
    _hydrationFuture = _hydrateCache();
  }

  TaskService _taskService;
  final TaskStorage _taskStorage;
  late final Future<void> _hydrationFuture;

  List<Task> _cachedTasks = <Task>[];

  List<Task> get tasks => List<Task>.unmodifiable(_cachedTasks);

  void updateTaskService(TaskService taskService) {
    if (!identical(_taskService, taskService)) {
      _taskService = taskService;
    }
  }

  Future<void> _hydrateCache() async {
    try {
      _cachedTasks = await _taskStorage.loadTasks();
    } catch (_) {
      _cachedTasks = <Task>[];
      await _taskStorage.clearTasks();
    }
  }

  Future<void> _ensureHydrated() {
    return _hydrationFuture;
  }

  Future<void> _persistCache() async {
    await _taskStorage.saveTasks(_cachedTasks);
  }

  Future<List<Task>> fetchTasks({bool forceRefresh = false}) async {
    await _ensureHydrated();

    if (!forceRefresh && _cachedTasks.isNotEmpty) {
      return List<Task>.unmodifiable(_cachedTasks);
    }

    try {
      final response = await _taskService.get<Map<String, dynamic>>('/api/tasks');
      final data = response.data ?? <String, dynamic>{};
      final taskList = TaskListResponse.fromJson(data);
      _cachedTasks = taskList.tasks;
      await _persistCache();
      notifyListeners();
    } on DioException catch (error) {
      if (_cachedTasks.isEmpty) {
        throw error;
      }
    }

    return List<Task>.unmodifiable(_cachedTasks);
  }

  Task? findCachedTask(String id) {
    for (final task in _cachedTasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Future<Task> createTask(Map<String, dynamic> payload) async {
    await _ensureHydrated();

    final response = await _taskService.post<Map<String, dynamic>>(
      '/api/tasks',
      data: payload,
    );
    final data = response.data ?? <String, dynamic>{};
    final task = TaskResponse.fromJson(data).task;
    _cachedTasks = List<Task>.from(_cachedTasks)..add(task);
    await _persistCache();
    notifyListeners();
    return task;
  }

  Future<Task> updateTask(String id, Map<String, dynamic> updates) async {
    await _ensureHydrated();

    final response = await _taskService.put<Map<String, dynamic>>(
      '/api/tasks/$id',
      data: updates,
    );
    final data = response.data ?? <String, dynamic>{};
    final updatedTask = TaskResponse.fromJson(data).task;

    final index = _cachedTasks.indexWhere((task) => task.id == id);
    if (index == -1) {
      _cachedTasks = List<Task>.from(_cachedTasks)..add(updatedTask);
    } else {
      final mutable = List<Task>.from(_cachedTasks);
      mutable[index] = updatedTask;
      _cachedTasks = mutable;
    }

    await _persistCache();
    notifyListeners();
    return updatedTask;
  }

  Future<void> deleteTask(String id) async {
    await _ensureHydrated();

    await _taskService.delete<Map<String, dynamic>>('/api/tasks/$id');
    _cachedTasks = _cachedTasks.where((task) => task.id != id).toList();
    await _persistCache();
    notifyListeners();
  }

  Future<void> completeByQr({required String id, required String code}) async {
    await _ensureHydrated();

    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      throw const FormatException('QR code cannot be empty.');
    }

    final response = await _taskService.post<Map<String, dynamic>>(
      '/api/tasks/$id/complete-qr',
      data: {'qr_code': trimmedCode},
    );
    final data = response.data ?? <String, dynamic>{};
    final completedTask = TaskResponse.fromJson(data).task;

    final index = _cachedTasks.indexWhere((task) => task.id == id);
    if (index == -1) {
      _cachedTasks = List<Task>.from(_cachedTasks)..add(completedTask);
    } else {
      final mutable = List<Task>.from(_cachedTasks);
      mutable[index] = completedTask;
      _cachedTasks = mutable;
    }

    await _persistCache();
    notifyListeners();
  }
}
