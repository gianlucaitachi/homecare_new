import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_bar_component.dart';
import '../components/bottom_bar_component.dart';
import '../components/qr_scan_button.dart';
import '../env.dart';
import '../repository/task_repository.dart';
import '../utils/app_router.dart';
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

  int _currentIndex = 0;

  Future<void> _openTaskForm() async {
    final result = await Navigator.of(context).pushNamed(AppRouter.taskFormRoute);
    if (!mounted) {
      return;
    }
    if (result == true) {
      await context
          .read<TaskRepository>()
          .fetchTasks(forceRefresh: true);
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
    await context.read<TaskRepository>().fetchTasks(forceRefresh: true);
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToScanTab() {
    if (_currentIndex == 1) {
      return;
    }
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarComponent(
        title: _titles[_currentIndex],
        actions: _currentIndex == 1
            ? null
            : [
                QrScanButton(
                  onPressed: _navigateToScanTab,
                  tooltip: 'Chuyển đến quét QR',
                ),
              ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          const TaskListView(),
          ScanView(
            baseUrl: Env.backendBaseUrl,
            onTaskCompleted: _handleScanCompleted,
            showAppBar: false,
          ),
          ProfileView(
            baseUrl: Env.backendBaseUrl,
            showScaffold: false,
          ),
        ],
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
