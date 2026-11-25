import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rmpzd/app/di.dart';
import 'package:rmpzd/app/main_navigation_screen.dart';
import 'package:rmpzd/features/auth/domain/entities/user_profile.dart';
import 'package:rmpzd/features/monitoring/presentation/pages/monitor_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('monitor enters the live inbox without bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(await _appFor(UserRole.monitor));

    expect(find.byType(MonitorHomePage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Nuevos'), findsOneWidget);
    expect(find.text('Mis casos'), findsOneWidget);
    expect(find.text('Cerrados'), findsOneWidget);
  });

  testWidgets('doctor retains the two existing navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(await _appFor(UserRole.doctor));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(2));
    expect(find.text('Triage'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.byType(MonitorHomePage), findsNothing);
  });

  testWidgets('admin retains the existing four navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(await _appFor(UserRole.admin));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(4));
    expect(find.text('Registros'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(MonitorHomePage), findsNothing);
  });
}

Future<Widget> _appFor(UserRole role) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return MultiProvider(
    providers: createAppProviders(
      supabaseClient: null,
      sharedPreferences: preferences,
    ),
    child: MaterialApp(home: MainNavigationScreen(profile: _profile(role))),
  );
}

UserProfile _profile(UserRole role) => UserProfile(
  id: '${role.name}-1',
  email: '${role.name}@example.test',
  fullName: '${role.label} de prueba',
  role: role,
  active: true,
);
