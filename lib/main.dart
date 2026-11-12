import 'package:flutter/widgets.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? supabaseClient;
  String? authInitializationError;
  try {
    final config = AppConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    supabaseClient = Supabase.instance.client;
  } catch (error, stackTrace) {
    authInitializationError = error.toString();
    debugPrint('No se pudo inicializar Supabase: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(
    RmpzdApp(
      supabaseClient: supabaseClient,
      sharedPreferences: sharedPreferences,
      authInitializationError: authInitializationError,
    ),
  );
}
