import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/task_card.dart';
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
    final tasks = context.watch<TaskRepository>().tasks;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshTasks,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (tasks.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildEmptyState(),
                  ),
                ),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  task: task,
                  onOpenActions: () => _openTaskActions(task),
                  onMarkDone: () => _handleMarkComplete(task),
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _isTaskCompleted(Task task) {
    final normalized = task.status.trim().toLowerCase();
    return normalized.contains('complete') || normalized == 'done';
  }

  Future<void> _openTaskActions(Task task) async {
    final canMarkDone = !_isTaskCompleted(task);
    final hasQrCode = task.qrCode.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Người phụ trách: ${task.assignee}'),
                    Text('Hạn: ${formatDueDate(task.dueDate)}'),
                    Text('Trạng thái: ${task.status}'),
                  ],
                ),
              ),
              if (hasQrCode)
                ListTile(
                  leading: const Icon(Icons.qr_code_2_outlined),
                  title: const Text('Mã QR'),
                  subtitle: SelectableText(task.qrCode),
                ),
              if (canMarkDone)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Đánh dấu hoàn thành'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _handleMarkComplete(task);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Đóng'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
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
