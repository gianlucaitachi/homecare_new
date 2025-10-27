import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../repository/task_repository.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  late Future<List<Task>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadTasks();
  }

  Future<List<Task>> _loadTasks({bool forceRefresh = false}) {
    final repository = context.read<TaskRepository>();
    return repository.fetchTasks(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() {
    setState(() {
      _loadFuture = _loadTasks(forceRefresh: true);
    });
    return _loadFuture;
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<TaskRepository>();
    final tasks = repository.tasks;

    return FutureBuilder<List<Task>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && tasks.isEmpty) {
          return _TaskListError(onRetry: _refresh);
        }

        if (tasks.isEmpty) {
          return const _TaskListEmpty();
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _TaskTile(task: task);
            },
          ),
        );
      },
    );
  }
}

class _TaskListEmpty extends StatelessWidget {
  const _TaskListEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'No tasks yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a task to get started.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskListError extends StatelessWidget {
  const _TaskListError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              'Failed to load tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try refreshing.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate;
    final dueDateText = dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No due date';
    final theme = Theme.of(context);
    final status = task.status;
    final statusColor = _statusColor(theme, status);

    return ListTile(
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description != null && task.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Assignee: ${task.assignee}'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Due: $dueDateText'),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
        ),
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code: ${task.qrCode}')),
        );
      },
    );
  }

  Color _statusColor(ThemeData theme, String status) {
    switch (status) {
      case 'completed':
        return theme.colorScheme.primary;
      case 'in_progress':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.secondary;
    }
  }
}
