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

  Future<void> _handleEditTask(Task task) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Chỉnh sửa "${task.title}" chưa được hỗ trợ.')),
    );
    await refreshTasks(forceRefresh: true);
  }

  Future<void> _handleMarkComplete(Task task) async {
    final repository = context.read<TaskRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.updateTask(task.id, {'status': 'completed'});
      messenger.showSnackBar(
        SnackBar(content: Text('Đã đánh dấu "${task.title}" hoàn thành.')),
      );
      await repository.fetchTasks(forceRefresh: true);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể hoàn thành tác vụ: $error')),
      );
    }
  }

  Future<void> _openTaskActions(Task task) async {
    final action = await showModalBottomSheet<_TaskAction>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final tiles = <Widget>[
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Chỉnh sửa tác vụ'),
            onTap: () => Navigator.pop(context, _TaskAction.edit),
          ),
        ];

        final isCompleted = task.status.toLowerCase().contains('complete') ||
            task.status.toLowerCase() == 'done';
        if (!isCompleted) {
          tiles.add(
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
              title: const Text('Đánh dấu hoàn thành'),
              onTap: () => Navigator.pop(context, _TaskAction.markDone),
            ),
          );
        }

        tiles.add(
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Hủy'),
            onTap: () => Navigator.pop(context),
          ),
        );

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tiles,
          ),
        );
      },
    );

    switch (action) {
      case _TaskAction.edit:
        await _handleEditTask(task);
        break;
      case _TaskAction.markDone:
        await _handleMarkComplete(task);
        break;
      default:
        break;
    }
  }
}

enum _TaskAction { edit, markDone }
