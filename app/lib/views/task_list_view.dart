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
                return _TaskCard(task: task);
              },
            ),
          );
        },
      ),
    );
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueDate = task.dueDate;
    final dueDateLabel = formatDueDate(dueDate);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
