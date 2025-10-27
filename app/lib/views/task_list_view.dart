import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../repository/task_repository.dart';
import 'widgets/task_card.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    final repository = context.read<TaskRepository>();
    _isFetching = repository.tasks.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateIfNeeded();
    });
  }

  Future<void> _hydrateIfNeeded() async {
    final repository = context.read<TaskRepository>();
    if (repository.tasks.isNotEmpty) {
      if (mounted && _isFetching) {
        setState(() {
          _isFetching = false;
        });
      }
      return;
    }

    if (!_isFetching && mounted) {
      setState(() {
        _isFetching = true;
      });
    }

    try {
      await repository.fetchTasks();
    } on DioException catch (error) {
      _showError('Failed to load tasks: ${error.message ?? 'Unknown error'}');
    } catch (_) {
      _showError('Failed to load tasks. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      } else {
        _isFetching = false;
      }
    }
  }

  Future<void> _handleRefresh(TaskRepository repository) async {
    try {
      await repository.fetchTasks(forceRefresh: true);
    } on DioException catch (error) {
      _showError('Failed to refresh tasks: ${error.message ?? 'Unknown error'}');
    } catch (_) {
      _showError('Failed to refresh tasks. Please try again.');
    }
  }

  Future<void> _handleMarkDone(TaskRepository repository, Task task) async {
    try {
      await repository
          .updateTask(task.id, const <String, dynamic>{'status': 'completed'});
      await repository.fetchTasks(forceRefresh: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked "${task.title}" as done.')),
      );
    } on DioException catch (error) {
      _showError('Failed to mark task as done: ${error.message ?? 'Unknown error'}');
    } catch (_) {
      _showError('Failed to mark task as done. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskRepository>(
      builder: (context, repository, _) {
        final tasks = repository.tasks;

        return RefreshIndicator(
          onRefresh: () => _handleRefresh(repository),
          child: tasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == tasks.length - 1 ? 0 : 12),
                      child: TaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        onTap: () => TaskCard.showActionSheet(
                          context: context,
                          task: task,
                          onMarkDone: () => _handleMarkDone(repository, task),
                        ),
                        onMarkDone: () => _handleMarkDone(repository, task),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (_isFetching) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 120),
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: const [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tasks yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Pull down to refresh or create a new task.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
