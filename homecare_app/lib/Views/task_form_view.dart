import 'package:flutter/material.dart';

class TaskFormView extends StatefulWidget {
  const TaskFormView({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  State<TaskFormView> createState() => _TaskFormViewState();
}

class _TaskFormViewState extends State<TaskFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _description = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 16),
              Text('Submitting to: ' + widget.baseUrl),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  _formKey.currentState?.save();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Task "' + _description + '" saved')),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
