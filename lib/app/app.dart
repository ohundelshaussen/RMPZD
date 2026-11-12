import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/domain/entities/user_profile.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import 'di.dart';
import 'main_navigation_screen.dart';

class RmpzdApp extends StatelessWidget {
  final List<SingleChildWidget>? providers;
  final SupabaseClient? supabaseClient;
  final SharedPreferences? sharedPreferences;
  final String? authInitializationError;

  const RmpzdApp({
    super.key,
    this.providers,
    this.supabaseClient,
    this.sharedPreferences,
    this.authInitializationError,
  });

  @override
  Widget build(BuildContext context) {
    final appProviders =
        providers ??
        createAppProviders(
          supabaseClient: supabaseClient,
          sharedPreferences:
              sharedPreferences ??
              (throw StateError('SharedPreferences no fue inicializado.')),
          authInitializationError: authInitializationError,
        );

    return MultiProvider(
      providers: appProviders,
      child: MaterialApp(
        title: 'RMPZD - Alerta Temprana Materna',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    switch (authProvider.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        return const LoginPage();
      case AuthStatus.authenticated:
        final UserProfile? profile = authProvider.profile;
        if (profile == null) {
          return const LoginPage();
        }
        return MainNavigationScreen(profile: profile);
    }
  }
}
