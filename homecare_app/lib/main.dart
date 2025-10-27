import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Repository/auth_repository.dart';
import 'Services/services.dart';
import 'Utils/app_router.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService.instance;
  final notificationPermissionGranted = await notificationService.initialize();
  final storedToken = await TokenStorage.instance.getToken();
  final hasToken = storedToken != null;

  runApp(
    HomecareApp(
      initialRoute: hasToken ? AppRouter.homeRoute : AppRouter.loginRoute,
      notificationService: notificationService,
      notificationPermissionDenied: !notificationPermissionGranted,
    ),
  );
}

class HomecareApp extends StatefulWidget {
  const HomecareApp({
    required this.initialRoute,
    required this.notificationService,
    required this.notificationPermissionDenied,
    super.key,
  });

  final String initialRoute;
  final NotificationService notificationService;
  final bool notificationPermissionDenied;

  @override
  State<HomecareApp> createState() => _HomecareAppState();
}

class _HomecareAppState extends State<HomecareApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _permissionMessageShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShowPermissionWarning();
  }

  void _maybeShowPermissionWarning() {
    if (!widget.notificationPermissionDenied || _permissionMessageShown) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_permissionMessageShown) {
        return;
      }
      final messenger = _scaffoldMessengerKey.currentState;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are disabled. Enable them in Settings to receive reminders.',
          ),
        ),
      );
      _permissionMessageShown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeShowPermissionWarning();
    return MultiProvider(
      providers: [
        Provider<NotificationService>.value(value: widget.notificationService),
        Provider<TokenStorage>.value(value: TokenStorage.instance),
        Provider<TaskStorage>.value(value: TaskStorage.instance),
        Provider<NotificationService>(create: (_) => const NotificationService()),
        ProxyProvider<TokenStorage, AuthService>(
          update: (_, tokenStorage, __) => AuthService(tokenStorage: tokenStorage),
        ),
        ProxyProvider2<AuthService, TokenStorage, AuthRepository>(
          update: (_, authService, tokenStorage, __) =>
              AuthRepository(authService: authService, tokenStorage: tokenStorage),
        ),
        ProxyProvider<AuthService, TaskService>(
          update: (_, authService, __) => TaskService(authService: authService),
        ),
        ChangeNotifierProxyProvider3<TaskService, TaskStorage,
            NotificationService, TaskRepository>(
          create: (_) => TaskRepository(),
          update: (_, taskService, taskStorage, notificationService, repository) {
            final repo = repository ?? TaskRepository(
              taskService: taskService,
              taskStorage: taskStorage,
              notificationService: notificationService,
            );
            repo.updateTaskService(taskService);
            repo.updateNotificationService(notificationService);
            return repo;
          },
        ),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: _scaffoldMessengerKey,
        title: 'Homecare',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        initialRoute: widget.initialRoute,
        onGenerateRoute: AppRouter.generateRoute,
        builder: (context, child) {
          return Banner(
            message: Env.backendBaseUrl,
            location: BannerLocation.topEnd,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
