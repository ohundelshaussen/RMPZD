import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectivityService {
  final Connectivity connectivity;
  final SupabaseClient? client;
  final Duration timeout;

  ConnectivityService({
    required this.connectivity,
    required this.client,
    this.timeout = const Duration(seconds: 3),
  });

  Stream<bool> get connectionChanges =>
      connectivity.onConnectivityChanged.asyncMap((results) async {
        if (results.every((result) => result == ConnectivityResult.none)) {
          return false;
        }
        return hasInternet();
      }).distinct();

  Future<bool> hasInternet() async {
    final results = await connectivity.checkConnectivity();
    if (results.every((result) => result == ConnectivityResult.none)) {
      return false;
    }

    final supabase = client;
    if (supabase == null) return false;
    try {
      await supabase.from('profiles').select('id').limit(1).timeout(timeout);
      return true;
    } on Exception {
      return false;
    }
  }
}
