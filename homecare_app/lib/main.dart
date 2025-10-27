import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Repository/auth_repository.dart';
import 'Repository/task_repository.dart';
import 'Services/auth_service.dart';
import 'Services/token_storage.dart';
import 'Services/task_service.dart';
import 'Services/task_storage.dart';
import 'Utils/app_router.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = await createAuthRepository();
  final hasToken = authRepository.getStoredToken() != null;

  runApp(
    HomecareApp(
      authRepository: authRepository,
      initialRoute: hasToken ? AppRouter.homeRoute : AppRouter.loginRoute,
    ),
  );
}

class HomecareApp extends StatelessWidget {
  const HomecareApp({
    required this.authRepository,
    required this.initialRoute,
    super.key,
  });

  final AuthRepository authRepository;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: TokenStorage.instance),
        Provider<TaskStorage>.value(value: TaskStorage.instance),
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
        ChangeNotifierProxyProvider2<TaskService, TaskStorage, TaskRepository>(
          create: (_) => TaskRepository(),
          update: (_, taskService, taskStorage, repository) {
            final repo = repository ??
                TaskRepository(taskService: taskService, taskStorage: taskStorage);
            repo.updateTaskService(taskService);
            return repo;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Homecare',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        initialRoute: initialRoute,
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
