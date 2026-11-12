import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatusDataSource {
  final Connectivity connectivity;

  NetworkStatusDataSource({required this.connectivity});

  Future<bool> hasConnection() async {
    final results = await connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Stream<bool> get connectionChanges => connectivity.onConnectivityChanged
      .map((results) => results.any((result) => result != ConnectivityResult.none));
}
