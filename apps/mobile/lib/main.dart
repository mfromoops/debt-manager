import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/app_state.dart';
import 'services/sync_service.dart';
import 'screens/home_shell.dart';

// Shared with the DebtFold marketing site.
const kCanvas = Color(0xFFFBFCFA);
const kSurface = Color(0xFFFFFFFF);
const kAccent = Color(0xFF2D6A4F);
const kAccentDark = Color(0xFF22533D);
const kAccentFocus = Color(0xFF91C2A8);
const kAccentPale = Color(0xFFBCE5CB);
const kInk = Color(0xFF1D2521);
const kSubtle = Color(0xFF6F7973);
const kSoft = Color(0xFFF3F7F4);
const kBorder = Color(0xFFDCE8E0);
const kHairline = Color(0xFFE8ECE9);
const kPagePadding = 24.0;
const kSectionGap = 32.0;
const kCardRadius = 12.0;

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

class DebtManagerApp extends StatefulWidget {
  const DebtManagerApp({super.key});

  @override
  State<DebtManagerApp> createState() => _DebtManagerAppState();
}

class _DebtManagerAppState extends State<DebtManagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (context.read<AuthService>().isAuthenticated) {
      unawaited(context.read<AppState>().syncNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DebtFold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kCanvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          primary: kAccent,
          surface: kSurface,
        ),
        fontFamily: 'DM Sans',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: kInk,
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.1,
          ),
          headlineMedium: TextStyle(
            color: kInk,
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
          ),
          titleLarge: TextStyle(
            color: kInk,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
          bodyMedium: TextStyle(color: kInk, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: kSubtle, fontSize: 12, height: 1.45),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kCanvas,
          foregroundColor: kInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          toolbarHeight: 64,
          titleSpacing: kPagePadding,
          titleTextStyle: TextStyle(
            color: kInk,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
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
              borderRadius: BorderRadius.circular(8),
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kAccent,
            side: const BorderSide(color: kBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          ),
        ),
        cardTheme: CardThemeData(
          color: kSurface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: kBorder),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kSurface,
          modalBackgroundColor: kSurface,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kInk,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: kAccent,
          textColor: kInk,
          contentPadding: EdgeInsets.symmetric(horizontal: kPagePadding),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kAccent, width: 1.5),
          ),
          labelStyle: const TextStyle(
            color: kSubtle,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}
