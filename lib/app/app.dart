import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../core/theme/app_theme.dart';
import 'di.dart';
import 'main_navigation_screen.dart';

class RmpzdApp extends StatelessWidget {
  final List<SingleChildWidget>? providers;

  const RmpzdApp({super.key, this.providers});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers ?? createAppProviders(),
      child: MaterialApp(
        title: 'RMPZD - Alerta Temprana Materna',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
