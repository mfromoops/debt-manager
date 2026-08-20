import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/app_state.dart';
import 'services/sync_service.dart';
import 'screens/home_shell.dart';

// Minimalist palette - Style 3
const kAccent = Color(0xFF2D6A4F); // forest green
const kInk = Color(0xFF111411);
const kSubtle = Color(0xFF8A8F8A);
const kHairline = Color(0xFFE7E9E7);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  appState.load();
  final authService = AuthService();
  authService.load();
  final syncService = SyncService();
  appState.configureSync(syncService);
  authService.addListener(() {
    unawaited(
      appState.setSyncSession(
        authService.isAuthenticated ? authService.validAccessToken : null,
        userId: authService.user?.id,
      ),
    );
  });
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: authService),
      ],
      child: const DebtManagerApp(),
    ),
  );
}

class DebtManagerApp extends StatelessWidget {
  const DebtManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DebtFold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          primary: kAccent,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: kInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: kInk,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.2,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: kHairline,
          thickness: 1,
          space: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : kSubtle,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? kAccent : kHairline,
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kAccent),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: kHairline),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kHairline),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kAccent, width: 1.5),
          ),
          labelStyle: TextStyle(color: kSubtle, fontWeight: FontWeight.w300),
        ),
      ),
      home: const HomeShell(),
    );
  }
}
