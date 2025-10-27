import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/task_list_response.dart';
import '../models/task_response.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../services/task_storage.dart';

class TaskRepository extends ChangeNotifier {
  TaskRepository({
    TaskService? taskService,
    TaskStorage? taskStorage,
    NotificationService? notificationService,
  })  : _taskService = taskService ?? TaskService(),
        _taskStorage = taskStorage ?? TaskStorage.instance,
        _notificationService = notificationService ?? NotificationService() {
    _hydrationFuture = _hydrateCache();
  }

  TaskService _taskService;
  NotificationService _notificationService;
  final TaskStorage _taskStorage;
  late final Future<void> _hydrationFuture;

  List<Task> _cachedTasks = <Task>[];
  Map<String, int> _scheduledNotificationIds = <String, int>{};

  List<Task> get tasks => List<Task>.unmodifiable(_cachedTasks);

  @visibleForTesting
  Map<String, int> get scheduledNotificationIds =>
      Map<String, int>.unmodifiable(_scheduledNotificationIds);

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
      _scheduledNotificationIds = <String, int>{};
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
    final dueDate = task.dueDate;
    if (_isTaskComplete(task) || !_isDueDateInFuture(dueDate)) {
      await _cancelScheduledNotification(task.id);
      return;
    }

    await _notificationService.init();

    final notificationId = _notificationIdForTask(task.id);
    await _notificationService.scheduleNotification(
      id: notificationId,
      title: task.title,
      body: 'Assigned to ${task.assignee}',
      scheduledDate: dueDate?.toLocal(),
      payload: task.id,
    );

    final mutable = Map<String, int>.from(_scheduledNotificationIds)
      ..[task.id] = notificationId;
    _scheduledNotificationIds = mutable;
    await _persistNotificationIds();
  }

  Future<void> _cancelScheduledNotification(String taskId) async {
    final notificationId =
        _scheduledNotificationIds[taskId] ?? _notificationIdForTask(taskId);
    await _notificationService.cancelNotification(notificationId);
    if (_scheduledNotificationIds.containsKey(taskId)) {
      final mutable = Map<String, int>.from(_scheduledNotificationIds)
        ..remove(taskId);
      _scheduledNotificationIds = mutable;
      await _persistNotificationIds();
    }
  }

  bool _isDueDateInFuture(DateTime? dueDate) {
    if (dueDate == null) {
      return false;
    }
    final now = DateTime.now().toUtc();
    return dueDate.toUtc().isAfter(now);
  }

  int _notificationIdForTask(String taskId) {
    const int seed = 31;
    int hash = 0;
    for (final codeUnit in taskId.codeUnits) {
      hash = (hash * seed + codeUnit) & 0x7fffffff;
    }
    if (hash == 0) {
      return taskId.codeUnits.isEmpty ? 1 : taskId.codeUnits.first;
    }
    return hash;
  }

  bool _isTaskComplete(Task task) {
    final normalized = task.status.trim().toLowerCase();
    return normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'done';
  }
}
