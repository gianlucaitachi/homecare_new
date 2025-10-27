import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../Models/task.dart';

class TaskStorage {
  TaskStorage._();

  static final TaskStorage instance = TaskStorage._();

  static const String tasksKey = 'cached_tasks';

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(tasksKey, encoded);
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

  Future<void> clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tasksKey);
  }
}
