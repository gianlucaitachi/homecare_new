import 'package:flutter/material.dart';

import '../Utils/app_router.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pushReplacementNamed(AppRouter.homeRoute),
          child: const Text('Enter Homecare'),
        ),
      ),
    );
  }
}
