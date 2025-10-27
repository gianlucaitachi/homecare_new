import 'package:flutter/material.dart';

import '../Views/home_view.dart';
import '../Views/login_view.dart';
import '../Views/profile_view.dart';
import '../Views/scan_view.dart';
import '../Views/task_form_view.dart';
import '../env.dart';

class AppRouter {
  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String taskFormRoute = '/task-form';
  static const String scanRoute = '/scan';
  static const String profileRoute = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginRoute:
        return MaterialPageRoute(builder: (_) => const LoginView());
      case homeRoute:
        return MaterialPageRoute(builder: (_) => HomeView(baseUrl: Env.backendBaseUrl));
      case taskFormRoute:
        return MaterialPageRoute(builder: (_) => TaskFormView(baseUrl: Env.backendBaseUrl));
      case scanRoute:
        return MaterialPageRoute(builder: (_) => ScanView(baseUrl: Env.backendBaseUrl));
      case profileRoute:
        return MaterialPageRoute(builder: (_) => ProfileView(baseUrl: Env.backendBaseUrl));
      default:
        return MaterialPageRoute(builder: (_) => const LoginView());
    }
  }
}
