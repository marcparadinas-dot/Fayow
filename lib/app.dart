// lib/app.dart

import 'package:flutter/material.dart';
import 'package:fayow/auth/auth_manager.dart';
import 'package:fayow/auth_screen.dart';
import 'package:fayow/map_screen.dart';

class FayowApp extends StatelessWidget {
  const FayowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaYoW',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const RootNavigator(),
    );
  }
}

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  final AuthManager _authManager = AuthManager();

  @override
  void initState() {
    super.initState();
    // Écoute les changements d'état d'authentification
    _authManager.authStateChanges.listen((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    if (_authManager.isLoggedIn) {
      return MapScreen(authManager: _authManager);
    } else {
      return AuthScreen(
        authManager: _authManager,
        onAuthSuccess: () => setState(() {}),
      );
    }
  }
}