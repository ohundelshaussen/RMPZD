import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../features/dashboard/presentation/pages/academic_dashboard_page.dart';
import '../features/history/presentation/pages/history_page.dart';
import '../features/triage/presentation/pages/triage_form_page.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TriageFormPage(),
    HistoryPage(),
    AcademicDashboardPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.2),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(
              Icons.favorite_rounded,
              color: AppColors.primary,
            ),
            label: 'Triage',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppColors.primary),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(
              Icons.insights_rounded,
              color: AppColors.primary,
            ),
            label: 'Métricas IA',
          ),
        ],
      ),
    );
  }
}
