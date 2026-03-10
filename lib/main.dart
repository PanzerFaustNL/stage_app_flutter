import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stage_app/screens/auth_gate.dart';
import 'package:stage_app/services/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local DB
  await AppDb.instance.init();

  // Supabase config from .env
  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    // App will still run, but sync/login won't work until configured.
    debugPrint('Supabase not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env');
  } else {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const StageApp());
}

class StageApp extends StatelessWidget {
  const StageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stage App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
