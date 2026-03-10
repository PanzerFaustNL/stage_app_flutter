import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stage_app/screens/home_screen.dart';
import 'package:stage_app/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool get _supabaseReady {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supabaseReady) {
      // Supabase not configured: run in local-only mode.
      return const HomeScreen(localOnly: true);
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return const HomeScreen(localOnly: false);
      },
    );
  }
}
