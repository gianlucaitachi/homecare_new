import 'task.dart';

class TaskResponse {
  const TaskResponse({required this.task});

  final Task task;

  factory TaskResponse.fromJson(Map<String, dynamic> json) {
    final taskJson = json['task'];
    if (taskJson is Map<String, dynamic>) {
      return TaskResponse(task: Task.fromJson(taskJson));
    }
    if (taskJson is Map) {
      return TaskResponse(task: Task.fromJson(Map<String, dynamic>.from(taskJson)));
    }
    throw const FormatException('Invalid task response payload');
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task.toJson(),
    };
  }
}
