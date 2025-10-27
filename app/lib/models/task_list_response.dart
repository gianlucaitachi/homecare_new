import 'task.dart';

class TaskListResponse {
  const TaskListResponse({required this.tasks});

  final List<Task> tasks;

  factory TaskListResponse.fromJson(Map<String, dynamic> json) {
    final tasksJson = json['tasks'];
    if (tasksJson is! List) {
      throw const FormatException('Invalid tasks list payload');
    }

    final tasks = tasksJson.map((task) {
      if (task is Map<String, dynamic>) {
        return Task.fromJson(task);
      }
      if (task is Map) {
        return Task.fromJson(Map<String, dynamic>.from(task));
      }
      throw const FormatException('Invalid task entry in payload');
    }).toList();

    return TaskListResponse(tasks: tasks);
  }

  Map<String, dynamic> toJson() {
    return {
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }
}
