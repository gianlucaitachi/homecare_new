import 'package:flutter/material.dart';

import '../env.dart';
import '../utils/app_router.dart';
import 'components/app_bar_component.dart';
import 'components/bottom_bar_component.dart';
import 'profile_view.dart';
import 'scan_view.dart';
import 'task_list_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _titles = <String>['Tasks', 'Scan', 'Profile'];

  final GlobalKey<TaskListViewState> _taskListKey = GlobalKey<TaskListViewState>();
  late final List<Widget> _pages;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      TaskListView(key: _taskListKey),
      ScanView(
        baseUrl: Env.backendBaseUrl,
        onTaskCompleted: _handleScanCompleted,
        showAppBar: false,
      ),
      ProfileView(
        baseUrl: Env.backendBaseUrl,
        showScaffold: false,
      ),
    ];
  }

  Future<void> _refreshTaskList() async {
    final state = _taskListKey.currentState;
    if (state != null) {
      await state.refreshTasks(forceRefresh: true);
    }
  }

  Future<void> _openTaskForm() async {
    final result = await Navigator.of(context).pushNamed(AppRouter.taskFormRoute);
    if (result == true) {
      await _refreshTaskList();
    }
  }

  Future<void> _handleScanCompleted() async {
    if (!mounted) {
      return;
    }
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }
    await _refreshTaskList();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarComponent(title: _titles[_currentIndex]),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomBarComponent(
        currentIndex: _currentIndex,
        onTabSelected: _onTabSelected,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openTaskForm,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
