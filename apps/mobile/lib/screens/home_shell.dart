import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import 'loans_overview_screen.dart';
import 'sign_in_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();

    if (!state.loaded || !auth.loaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const SignInScreen();
    }

    return const LoansOverviewScreen();
  }
}
