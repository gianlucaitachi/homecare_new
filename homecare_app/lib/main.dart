import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Repositories/auth_repository.dart';
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
        Provider<AuthRepository>.value(value: authRepository),
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
