import 'package:voice_note/screens/auth_gate.dart';
import 'package:voice_note/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://knmsboniapwocbcyvolp.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtubXNib25pYXB3b2NiY3l2b2xwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNDAzMjIsImV4cCI6MjEwNTcxNjMyMn0.5GNcW_Z8koCcQ56ErA-XBeDCCdWaOnaorqCNb109rTI';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Notes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
