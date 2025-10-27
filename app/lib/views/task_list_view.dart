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
  bool _initialFetchScheduled = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialFetchScheduled) {
      return;
    }
    _initialFetchScheduled = true;
    final repository = context.read<TaskRepository>();
    if (repository.tasks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        refreshTasks(forceRefresh: false);
      });
    }
  }

  Future<void> refreshTasks({bool forceRefresh = true}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await context
          .read<TaskRepository>()
          .fetchTasks(forceRefresh: forceRefresh);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load tasks: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleMarkDone(Task task) async {
    final repository = context.read<TaskRepository>();
    final normalizedStatus = task.status.toLowerCase();
    if (normalizedStatus == 'completed' || normalizedStatus == 'complete') {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task is already completed.')),
      );
      return;
    }

    try {
      await repository.updateTask(task.id, <String, dynamic>{'status': 'completed'});
      await repository.fetchTasks(forceRefresh: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${task.title}" as completed.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark task as done: $error'),
        ),
      );
    }
  }

  void _openTaskActions(Task task) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return TaskActionSheet(
          task: task,
          onMarkDone: task.status.toLowerCase() == 'completed'
              ? null
              : () async {
                  Navigator.of(context).pop();
                  await _handleMarkDone(task);
                },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Text(
        'No tasks available yet. Pull down to refresh.',
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<TaskRepository>();
    final tasks = repository.tasks;

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

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onMarkDone,
  });

  final Task task;
  final VoidCallback? onTap;
  final Future<void> Function()? onMarkDone;

  bool get _isCompleted {
    final normalized = task.status.toLowerCase();
    return normalized == 'completed' || normalized == 'complete';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueDate = task.dueDate;
    final dueDateLabel =
        dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No due date';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(status: task.status),
                ],
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Text('Assignee: ${task.assignee}'),
              const SizedBox(height: 4),
              Text('Due: $dueDateLabel'),
              const SizedBox(height: 8),
              SelectableText(
                'QR Code: ${task.qrCode}',
                style: theme.textTheme.bodySmall,
              ),
              if (!_isCompleted && onMarkDone != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final callback = onMarkDone;
                      if (callback == null) {
                        return;
                      }
                      await callback();
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark as done'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
