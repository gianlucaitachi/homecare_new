import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../Models/task.dart';
import '../Models/task_list_response.dart';
import '../Models/task_response.dart';
import '../Services/notification_service.dart';
import '../Services/task_service.dart';
import '../Services/task_storage.dart';

class TaskRepository extends ChangeNotifier {
  TaskRepository({
    TaskService? taskService,
    TaskStorage? taskStorage,
    NotificationService? notificationService,
  })  : _taskService = taskService ?? TaskService(),
        _taskStorage = taskStorage ?? TaskStorage.instance,
        _notificationService = notificationService ?? const NotificationService() {
    _hydrationFuture = _hydrateCache();
  }

  TaskService _taskService;
  NotificationService _notificationService;
  final TaskStorage _taskStorage;
  late final Future<void> _hydrationFuture;

  List<Task> _cachedTasks = <Task>[];
  Map<String, String> _scheduledNotificationIds = <String, String>{};

  List<Task> get tasks => List<Task>.unmodifiable(_cachedTasks);

  @visibleForTesting
  Map<String, String> get scheduledNotificationIds =>
      Map<String, String>.unmodifiable(_scheduledNotificationIds);

  void updateTaskService(TaskService taskService) {
    if (!identical(_taskService, taskService)) {
      _taskService = taskService;
    }
  }

  void updateNotificationService(NotificationService notificationService) {
    if (!identical(_notificationService, notificationService)) {
      _notificationService = notificationService;
    }
  }

  Future<void> _hydrateCache() async {
    try {
      _cachedTasks = await _taskStorage.loadTasks();
    } catch (_) {
      _cachedTasks = <Task>[];
      await _taskStorage.clearTasks();
    }

    try {
      _scheduledNotificationIds = await _taskStorage.loadNotificationIds();
    } catch (_) {
      _scheduledNotificationIds = <String, String>{};
      await _taskStorage.clearNotificationIds();
    }
  }

  Future<void> _ensureHydrated() {
    return _hydrationFuture;
  }

  Future<void> _persistCache() async {
    await _taskStorage.saveTasks(_cachedTasks);
  }

  Future<void> _persistNotificationIds() async {
    await _taskStorage.saveNotificationIds(_scheduledNotificationIds);
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
    await _scheduleNotificationForTask(task);
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
    await _scheduleNotificationForTask(updatedTask);
    notifyListeners();
    return updatedTask;
  }

  Future<void> deleteTask(String id) async {
    await _ensureHydrated();

    await _taskService.delete<Map<String, dynamic>>('/api/tasks/$id');
    _cachedTasks = _cachedTasks.where((task) => task.id != id).toList();
    await _persistCache();
    await _cancelScheduledNotification(id);
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
    await _cancelScheduledNotification(id);
    notifyListeners();
  }

  Future<void> _scheduleNotificationForTask(Task task) async {
    if (_isTaskComplete(task) || !_isDueDateInFuture(task)) {
      await _cancelScheduledNotification(task.id);
      return;
    }

    final notificationId =
        await _notificationService.scheduleNotification(task);
    if (notificationId == null || notificationId.isEmpty) {
      if (_scheduledNotificationIds.containsKey(task.id)) {
        final mutable = Map<String, String>.from(_scheduledNotificationIds)
          ..remove(task.id);
        _scheduledNotificationIds = mutable;
        await _persistNotificationIds();
      }
      return;
    }

    if (_scheduledNotificationIds[task.id] == notificationId) {
      return;
    }

    final mutable = Map<String, String>.from(_scheduledNotificationIds)
      ..[task.id] = notificationId;
    _scheduledNotificationIds = mutable;
    await _persistNotificationIds();
  }

  Future<void> _cancelScheduledNotification(String taskId) async {
    await _notificationService.cancelNotification(taskId);
    if (_scheduledNotificationIds.containsKey(taskId)) {
      final mutable = Map<String, String>.from(_scheduledNotificationIds)
        ..remove(taskId);
      _scheduledNotificationIds = mutable;
      await _persistNotificationIds();
    }
  }

  bool _isDueDateInFuture(Task task) {
    final dueDate = DateTime.tryParse(task.dueDate);
    if (dueDate == null) {
      return false;
    }
    final now = DateTime.now().toUtc();
    return dueDate.toUtc().isAfter(now);
  }

  bool _isTaskComplete(Task task) {
    final normalized = task.status.trim().toLowerCase();
    return normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'done';
  }
}
