import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../repository/task_repository.dart';
import '../components/task_card.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  TaskListViewState createState() => TaskListViewState();
}

class TaskListViewState extends State<TaskListView> {
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _loadTasks();
  }

  Future<List<Task>> _loadTasks({bool forceRefresh = false}) {
    final repository = context.read<TaskRepository>();
    return repository.fetchTasks(forceRefresh: forceRefresh);
  }

  Future<void> refreshTasks({bool forceRefresh = true}) async {
    setState(() {
      _tasksFuture = _loadTasks(forceRefresh: forceRefresh);
    });
    await _tasksFuture;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          final repository = context.watch<TaskRepository>();
          final tasks = repository.tasks;

          if (snapshot.connectionState == ConnectionState.waiting &&
              tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && tasks.isEmpty) {
            return _RefreshableMessage(
              onRefresh: refreshTasks,
              message:
                  'Failed to load tasks. Pull down to try again.',
            );
          }

          if (tasks.isEmpty) {
            return _RefreshableMessage(
              onRefresh: refreshTasks,
              message:
                  'No tasks available yet. Pull down to refresh.',
            );
          }

          return RefreshIndicator(
            onRefresh: refreshTasks,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  task: task,
                  onEdit: () => _handleEditTask(task),
                  onMarkComplete: () => _handleMarkComplete(task),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleEditTask(Task task) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Chỉnh sửa "${task.title}" chưa được hỗ trợ.')),
    );
  }

  Future<void> _handleMarkComplete(Task task) async {
    final repository = context.read<TaskRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.updateTask(task.id, {'status': 'completed'});
      messenger.showSnackBar(
        SnackBar(content: Text('Đã đánh dấu "${task.title}" hoàn thành.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể hoàn thành tác vụ: $error')),
      );
    }
  }
}

class _RefreshableMessage extends StatelessWidget {
  const _RefreshableMessage({
    required this.onRefresh,
    required this.message,
  });

  final Future<void> Function({bool forceRefresh}) onRefresh;
  final String message;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(      
      onRefresh: () => onRefresh(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
