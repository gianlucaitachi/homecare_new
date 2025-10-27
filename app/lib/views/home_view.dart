import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../env.dart';
import '../repository/task_repository.dart';
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
  late final List<Widget> _pages;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages = const <Widget>[
      TaskListView(),
      ScanView(baseUrl: Env.backendBaseUrl),
      ProfileView(baseUrl: Env.backendBaseUrl),
    ];
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _onAddTask() async {
    final result = await Navigator.of(context).pushNamed(AppRouter.taskFormRoute);
    if (!mounted) {
      return;
    }
    if (result == true) {
      await context.read<TaskRepository>().fetchTasks(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarComponent(
        title: _titles[_currentIndex],
      ),
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
              onPressed: _onAddTask,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
