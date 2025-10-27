import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onReschedule,
    this.onMarkComplete,
    this.onDelete,
  });

  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onReschedule;
  final VoidCallback? onMarkComplete;
  final VoidCallback? onDelete;

  bool get _hasActions =>
      onEdit != null ||
      onReschedule != null ||
      onMarkComplete != null ||
      onDelete != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverdue = _isOverdue(task);
    final dueDateText = _formatDueDate(task.dueDate);
    final statusText = _formatStatus(task.status);
    final statusColor = _statusColor(task.status, colorScheme);
    final statusTextColor = _statusTextColor(task.status, colorScheme);

    final backgroundColor = isOverdue
        ? colorScheme.errorContainer.withOpacity(0.25)
        : theme.cardColor;

    return Card(
      elevation: isOverdue ? 4 : 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusChip(
                              label: statusText,
                              color: statusColor,
                              textColor: statusTextColor,
                            ),
                            if (dueDateText != null)
                              _InfoChip(
                                icon: Icons.event,
                                label: dueDateText,
                                isWarning: isOverdue,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_hasActions)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showActionsSheet(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.assignee,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (task.description != null && task.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  task.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme scheme) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'done') {
      return scheme.primaryContainer;
    }
    if (normalized == 'in_progress' ||
        normalized == 'in progress' ||
        normalized == 'active') {
      return scheme.secondaryContainer;
    }
    if (normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'failed') {
      return scheme.errorContainer;
    }
    if (normalized == 'pending' || normalized == 'awaiting') {
      return scheme.tertiaryContainer;
    }
    return scheme.surfaceVariant;
  }

  Color _statusTextColor(String status, ColorScheme scheme) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'done') {
      return scheme.onPrimaryContainer;
    }
    if (normalized == 'in_progress' ||
        normalized == 'in progress' ||
        normalized == 'active') {
      return scheme.onSecondaryContainer;
    }
    if (normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'failed') {
      return scheme.onErrorContainer;
    }
    if (normalized == 'pending' || normalized == 'awaiting') {
      return scheme.onTertiaryContainer;
    }
    return scheme.onSurfaceVariant;
  }

  String? _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) {
      return null;
    }
    final localDueDate = dueDate.toLocal();
    final formatter = DateFormat('MMM d, yyyy • h:mm a');
    return formatter.format(localDueDate);
  }

  String _formatStatus(String status) {
    final normalized = status.trim();
    if (normalized.isEmpty) {
      return 'Unknown';
    }
    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) =>
            segment.substring(0, 1).toUpperCase() + segment.substring(1))
        .join(' ');
  }

  bool _isOverdue(Task task) {
    final dueDate = task.dueDate;
    if (dueDate == null) {
      return false;
    }
    final normalized = task.status.trim().toLowerCase();
    final isComplete =
        normalized == 'completed' || normalized == 'complete' || normalized == 'done';
    if (isComplete) {
      return false;
    }
    return dueDate.toUtc().isBefore(DateTime.now().toUtc());
  }

  void _showActionsSheet(BuildContext context) {
    if (!_hasActions) {
      return;
    }

    final actions = <_SheetAction>[
      if (onEdit != null)
        _SheetAction(
          icon: Icons.edit_outlined,
          label: 'Edit task',
          onPressed: onEdit!,
        ),
      if (onReschedule != null)
        _SheetAction(
          icon: Icons.schedule,
          label: 'Reschedule',
          onPressed: onReschedule!,
        ),
      if (onMarkComplete != null)
        _SheetAction(
          icon: Icons.check_circle_outline,
          label: 'Mark as complete',
          onPressed: onMarkComplete!,
        ),
      if (onDelete != null)
        _SheetAction(
          icon: Icons.delete_outline,
          label: 'Delete',
          onPressed: onDelete!,
          isDestructive: true,
        ),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final action = actions[index];
              final tileColor = action.isDestructive
                  ? Theme.of(sheetContext).colorScheme.error.withOpacity(0.08)
                  : null;
              final textColor = action.isDestructive
                  ? Theme.of(sheetContext).colorScheme.error
                  : null;
              return Material(
                color: tileColor,
                child: ListTile(
                  leading: Icon(action.icon, color: textColor),
                  title: Text(
                    action.label,
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.onPressed();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SheetAction {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = isWarning
        ? colorScheme.error.withOpacity(0.08)
        : colorScheme.surfaceVariant;
    final foreground = isWarning ? colorScheme.error : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
