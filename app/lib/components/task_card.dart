import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/date_format.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onOpenActions,
    this.onMarkDone,
  });

  final Task task;
  final VoidCallback onOpenActions;
  final VoidCallback? onMarkDone;

  bool get _isCompleted {
    final value = task.status.toLowerCase();
    return value.contains('complete') || value == 'done';
  }

  bool get _isOverdue {
    final dueDate = task.dueDate;
    if (dueDate == null || _isCompleted) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(dueDate);
  }

  Color _statusBackgroundColor(ColorScheme colors) {
    final value = task.status.toLowerCase();
    if (value.contains('complete')) {
      return colors.secondaryContainer;
    }
    if (value.contains('progress') || value.contains('doing')) {
      return colors.tertiaryContainer;
    }
    if (value.contains('pending') || value.contains('todo')) {
      return colors.primaryContainer;
    }
    return colors.surfaceVariant;
  }

  Color _statusForegroundColor(ColorScheme colors) {
    final value = task.status.toLowerCase();
    if (value.contains('complete')) {
      return colors.onSecondaryContainer;
    }
    if (value.contains('progress') || value.contains('doing')) {
      return colors.onTertiaryContainer;
    }
    if (value.contains('pending') || value.contains('todo')) {
      return colors.onPrimaryContainer;
    }
    return colors.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final cardColor = _isOverdue
        ? colors.errorContainer
        : theme.cardTheme.color ?? theme.colorScheme.surface;
    final textColor = _isOverdue ? colors.onErrorContainer : null;
    final canMarkDone = !_isCompleted && onMarkDone != null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        color: textColor ?? theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Người phụ trách: ${task.assignee}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor?.withOpacity(0.9) ??
                            theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (canMarkDone)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  color: textColor ?? colors.primary,
                  tooltip: 'Đánh dấu hoàn thành',
                  onPressed: onMarkDone,
                ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                color: textColor ?? theme.iconTheme.color,
                tooltip: 'Tùy chọn',
                onPressed: onOpenActions,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(task.status),
                backgroundColor: _statusBackgroundColor(colors),
                labelStyle: TextStyle(color: _statusForegroundColor(colors)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: textColor ?? colors.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatDueDate(task.dueDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: _isOverdue ? FontWeight.w600 : FontWeight.normal,
                      color: _isOverdue
                          ? (textColor ?? colors.error)
                          : textColor ?? theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (task.description != null && task.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              task.description!,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ],
          if (task.qrCode.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.qr_code_2_outlined,
                  color: textColor ?? colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    task.qrCode,
                    style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      elevation: _isOverdue ? 4 : 1,
      child: InkWell(
        onTap: onOpenActions,
        child: content,
      ),
    );
  }
}
