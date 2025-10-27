import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Utils/app_router.dart';
import 'env.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HomecareApp());
}

class HomecareApp extends StatelessWidget {
  const HomecareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: const [],
      child: MaterialApp(
        title: 'Homecare',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        initialRoute: AppRouter.loginRoute,
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
