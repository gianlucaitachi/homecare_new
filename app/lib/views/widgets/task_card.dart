import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';

typedef TaskAsyncCallback = Future<void> Function();

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onMarkDone,
  });

  final Task task;
  final VoidCallback? onTap;
  final TaskAsyncCallback? onMarkDone;

  static Future<void> showActionSheet({
    required BuildContext context,
    required Task task,
    TaskAsyncCallback? onMarkDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(
                  task.title,
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text('Assigned to ${task.assignee}'),
              ),
              if (onMarkDone != null)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Mark as done'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onMarkDone();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Close'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate;
    final dueDateLabel = dueDate != null
        ? DateFormat.yMMMMd().format(dueDate.toLocal())
        : 'No due date';

    final statusStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _statusColor(context, task.status),
          fontWeight: FontWeight.w600,
        );

    return Card(
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (onMarkDone != null)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Mark as done',
                      onPressed: () async {
                        await onMarkDone?.call();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Assigned to ${task.assignee}'),
              const SizedBox(height: 4),
              Text('Due: $dueDateLabel'),
              const SizedBox(height: 8),
              Text('Status: ${task.status}', style: statusStyle),
              if (task.description != null && task.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color? _statusColor(BuildContext context, String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'completed':
      case 'complete':
      case 'done':
        return Colors.green.shade700;
      case 'in_progress':
      case 'in progress':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).textTheme.bodySmall?.color;
    }
  }
}
