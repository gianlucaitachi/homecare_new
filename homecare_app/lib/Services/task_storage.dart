import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../Models/task.dart';

class TaskStorage {
  TaskStorage._();

  static final TaskStorage instance = TaskStorage._();

  static const String tasksKey = 'cached_tasks';
  static const String notificationIdsKey = 'task_notification_ids';

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(tasksKey, encoded);
  }

  Future<void> saveNotificationIds(Map<String, String> notificationIds) async {
    final prefs = await SharedPreferences.getInstance();
    if (notificationIds.isEmpty) {
      await prefs.remove(notificationIdsKey);
      return;
    }

    final encoded = jsonEncode(notificationIds);
    await prefs.setString(notificationIdsKey, encoded);
  }

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(tasksKey);
    if (raw == null || raw.isEmpty) {
      return <Task>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Invalid cached tasks payload');
    }

    return decoded.map((entry) {
      if (entry is Map<String, dynamic>) {
        return Task.fromJson(entry);
      }
      if (entry is Map) {
        return Task.fromJson(Map<String, dynamic>.from(entry));
      }
      throw const FormatException('Invalid cached task entry');
    }).toList();
  }

  Future<Map<String, String>> loadNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(notificationIdsKey);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    }
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded as Map);
      return map.map((key, value) => MapEntry(key, value.toString()));
    }

    throw const FormatException('Invalid notification ids payload');
  }

  Future<void> clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tasksKey);
    await prefs.remove(notificationIdsKey);
  }

  Future<void> clearNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(notificationIdsKey);
  }
}
