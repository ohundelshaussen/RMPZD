import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/monitoring_case.dart';
import 'monitoring_notification_service.dart';

class LocalMonitoringNotificationService
    implements MonitoringNotificationService {
  static const _channel = AndroidNotificationChannel(
    'emergencias',
    'Emergencias',
    description: 'Alertas de alto riesgo para el equipo monitor.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _openedCases =
      StreamController<String>.broadcast();
  String? _initialCaseId;
  bool _initialized = false;

  LocalMonitoringNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Stream<String> get openedCaseIds => _openedCases.stream;

  @override
  String? takeInitialCaseId() {
    final caseId = _initialCaseId;
    _initialCaseId = null;
    return caseId;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _initialized = true;
      return;
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final caseId = response.payload;
        if (caseId != null && caseId.isNotEmpty) _openedCases.add(caseId);
      },
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _initialCaseId = launchDetails?.notificationResponse?.payload;
    }
    _initialized = true;
  }

  @override
  Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  @override
  Future<void> show(MonitoringAlert alert) async {
    if (!_initialized) await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    await _plugin.show(
      id: alert.caseId.hashCode & 0x7fffffff,
      title: 'RMPZD',
      body: alert.notificationText,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Emergencias',
          channelDescription: 'Alertas de alto riesgo para el equipo monitor.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: alert.caseId,
    );
  }

  static const _channelId = 'emergencias';
}
