import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onMarkDone,
  });

  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onMarkDone;

  bool get _isOverdue {
    final dueDate = task.dueDate;
    if (dueDate == null) {
      return false;
    }
    return dueDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = _isOverdue;
    final dueDateText = task.dueDate != null
        ? DateFormat('MMM d, yyyy').format(task.dueDate!.toLocal())
        : 'No due date';

    final statusChipTheme = _buildStatusChipTheme(theme, task.status);

    return Card(
      color: isOverdue
          ? Color.alphaBlend(
              theme.colorScheme.error.withOpacity(0.08),
              theme.cardColor,
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue
            ? BorderSide(color: theme.colorScheme.error, width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: () => _showActionsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assigned to ${task.assignee}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusChip(
                        label: statusChipTheme.label,
                        backgroundColor: statusChipTheme.backgroundColor,
                        textColor: statusChipTheme.textColor,
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Task actions',
                        onPressed: () => _showActionsSheet(context),
                      ),
                    ],
                  ),
                ],
              ),
              if (task.description != null && task.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  task.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 18,
                    color: isOverdue
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dueDateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isOverdue ? theme.colorScheme.error : theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Task'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Mark as Done'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onMarkDone?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  _StatusChipTheme _buildStatusChipTheme(ThemeData theme, String status) {
    final normalized = status.toLowerCase();
    Color background;
    Color textColor;
    switch (normalized) {
      case 'completed':
        background = theme.colorScheme.primary.withOpacity(0.12);
        textColor = theme.colorScheme.primary;
        break;
      case 'in_progress':
        background = theme.colorScheme.tertiary.withOpacity(0.12);
        textColor = theme.colorScheme.tertiary;
        break;
      case 'pending':
        background = theme.colorScheme.secondaryContainer.withOpacity(0.32);
        textColor = theme.colorScheme.onSecondaryContainer;
        break;
      default:
        background = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return _StatusChipTheme(
      label: normalized.replaceAll('_', ' ').toUpperCase(),
      backgroundColor: background,
      textColor: textColor,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ) ??
            TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
      ),
      backgroundColor: backgroundColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusChipTheme {
  const _StatusChipTheme({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}
