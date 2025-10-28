import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/app_bar_component.dart';
import '../repository/task_repository.dart';

class TaskFormView extends StatefulWidget {
  const TaskFormView({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  State<TaskFormView> createState() => _TaskFormViewState();
}

class _TaskFormViewState extends State<TaskFormView> {
  static const _titleFieldKey = ValueKey('taskForm_titleField');
  static const _descriptionFieldKey = ValueKey('taskForm_descriptionField');
  static const _assigneeFieldKey = ValueKey('taskForm_assigneeField');
  static const _dueDateFieldKey = ValueKey('taskForm_dueDateField');
  static const _statusFieldKey = ValueKey('taskForm_statusField');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _assigneeController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  final List<String> _statusOptions = const <String>[
    'pending',
    'in_progress',
    'completed',
  ];

  bool _isSubmitting = false;
  String _status = 'pending';
  DateTime? _selectedDueDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDueDate = picked;
      _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final repository = context.read<TaskRepository>();
    final dueDateInput = _dueDateController.text.trim();
    final parsedDueDate = _selectedDueDate ?? DateTime.tryParse(dueDateInput);

    if (parsedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid due date.')),
      );
      return;
    }

    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assignee': _assigneeController.text.trim(),
      'dueDate': DateFormat('yyyy-MM-dd').format(parsedDueDate),
      'status': _status,
    };

    setState(() {
      _isSubmitting = true;
    });

    try {
      await repository.createTask(payload);
      await repository.fetchTasks(forceRefresh: true);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create task: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarComponent(title: 'Task Form'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSubmitting) const LinearProgressIndicator(),
                if (_isSubmitting) const SizedBox(height: 16),
                TextFormField(
                  key: _titleFieldKey,
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter a task title',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Title is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: _descriptionFieldKey,
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Provide more details about the task',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Description is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: _assigneeFieldKey,
                  controller: _assigneeController,
                  decoration: const InputDecoration(
                    labelText: 'Assignee',
                    hintText: 'Who is responsible for this task?',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Assignee is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: _dueDateFieldKey,
                  controller: _dueDateController,
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickDueDate,
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Due date is required.';
                    }
                    if (DateTime.tryParse(trimmed) == null) {
                      return 'Enter a valid date (YYYY-MM-DD).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: _statusFieldKey,
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statusOptions
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status.replaceAll('_', ' ').toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _status = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                Text('Submitting to: ${widget.baseUrl}'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
