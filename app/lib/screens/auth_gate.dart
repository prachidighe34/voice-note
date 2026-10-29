import 'package:voice_note/screens/home_page.dart';
import 'package:voice_note/screens/login_page.dart';
import 'package:voice_note/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root screen-switcher: shows HomePage when logged in, LoginPage when
/// not — and reacts live to sign-in/sign-out, so no manual navigation
/// call is needed after a successful login or signOut().
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final isLoggedIn = authService.isLoggedIn;
        return isLoggedIn ? const HomePage() : const LoginPage();
      },
    );
  }
}
