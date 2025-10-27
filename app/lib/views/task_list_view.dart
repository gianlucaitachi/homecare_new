import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../repository/task_repository.dart';
import '../widgets/task_action_sheet.dart';
import '../widgets/task_card.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateIfNecessary());
    });
  }

  Future<void> _hydrateIfNecessary() async {
    final repository = context.read<TaskRepository>();
    if (repository.tasks.isNotEmpty) {
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    try {
      await repository.fetchTasks();
    } on DioException catch (error) {
      _showError(_messageFromDio(error) ??
          'Failed to load tasks. Please try pulling to refresh.');
    } catch (_) {
      _showError('Failed to load tasks. Please try pulling to refresh.');
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _refreshTasks(TaskRepository repository) async {
    try {
      await repository.fetchTasks(forceRefresh: true);
    } on DioException catch (error) {
      _showError(
        _messageFromDio(error) ?? 'Failed to refresh tasks. Please try again.',
      );
    } catch (_) {
      _showError('Failed to refresh tasks. Please try again.');
    }
  }

  Future<void> _markTaskComplete(Task task) async {
    try {
      final repository = context.read<TaskRepository>();
      await repository.updateTask(task.id, const {'status': 'completed'});
      await repository.fetchTasks(forceRefresh: true);
      if (!mounted) {
        return;
      }
      final title = task.title.trim();
      final message = title.isEmpty
          ? 'Task marked as complete.'
          : 'Marked "$title" as complete.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on DioException catch (error) {
      _showError(
        _messageFromDio(error) ??
            'Failed to mark the task as complete. Please try again.',
      );
    } catch (_) {
      _showError('Failed to mark the task as complete. Please try again.');
    }
  }

  Future<void> _showTaskActionSheet(Task task) {
    return TaskActionSheet.show(context: context, task: task);
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _messageFromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data as Map);
      final message = map['message'] ?? map['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskRepository>(
      builder: (context, repository, _) {
        final tasks = repository.tasks;

        return RefreshIndicator(
          onRefresh: () => _refreshTasks(repository),
          child: tasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TaskCard(
                        task: task,
                        onTap: () => _handleTap(task),
                        onMarkDone: () => _handleMarkDone(task),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _handleTap(Task task) {
    unawaited(_showTaskActionSheet(task));
  }

  void _handleMarkDone(Task task) {
    unawaited(_markTaskComplete(task));
  }

  Widget _buildEmptyState() {
    if (_isInitializing) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 48),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt, size: 72, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tasks available right now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Pull down to refresh or create a new task to get started.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
