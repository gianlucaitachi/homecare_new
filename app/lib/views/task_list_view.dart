import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../repository/task_repository.dart';
import '../utils/date_format.dart';

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
      child: RefreshIndicator(
        onRefresh: () => refreshTasks(forceRefresh: true),
        child: tasks.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: _buildEmptyState(),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (BuildContext context, int index) {
                  final task = tasks[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == tasks.length - 1 ? 0 : 12),
                    child: TaskCard(
                      task: task,
                      onTap: () => _openTaskActions(task),
                      onMarkDone: () async => _handleMarkDone(task),
                    ),
                  );
                },
              ),
      ),
    );
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

class TaskActionSheet extends StatelessWidget {
  const TaskActionSheet({
    super.key,
    required this.task,
    this.onMarkDone,
  });

  final Task task;
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Assignee: ${task.assignee}'),
            const SizedBox(height: 4),
            Text('Due: $dueDateLabel'),
            const SizedBox(height: 4),
            Text('Status: ${task.status}'),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(task.description!),
            ],
            const SizedBox(height: 12),
            SelectableText('QR Code: ${task.qrCode}'),
            const SizedBox(height: 16),
            if (!_isCompleted && onMarkDone != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Mark as done'),
                onTap: () async {
                  final callback = onMarkDone;
                  if (callback == null) {
                    return;
                  }
                  await callback();
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color _backgroundColor(BuildContext context) {
    final lower = status.toLowerCase();
    final theme = Theme.of(context);
    if (lower.contains('complete')) {
      return theme.colorScheme.secondaryContainer;
    }
    if (lower.contains('progress')) {
      return theme.colorScheme.tertiaryContainer;
    }
    return theme.colorScheme.primaryContainer;
  }

  Color _foregroundColor(BuildContext context) {
    final lower = status.toLowerCase();
    final theme = Theme.of(context);
    if (lower.contains('complete')) {
      return theme.colorScheme.onSecondaryContainer;
    }
    if (lower.contains('progress')) {
      return theme.colorScheme.onTertiaryContainer;
    }
    return theme.colorScheme.onPrimaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      backgroundColor: _backgroundColor(context),
      labelStyle: TextStyle(color: _foregroundColor(context)),
    );
  }
}
