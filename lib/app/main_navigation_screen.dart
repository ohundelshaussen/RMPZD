import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../features/auth/domain/entities/user_profile.dart';
import '../features/dashboard/presentation/pages/academic_dashboard_page.dart';
import '../features/history/presentation/pages/history_page.dart';
import '../features/triage/presentation/pages/triage_form_page.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserProfile profile;

  const MainNavigationScreen({required this.profile, super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  List<_NavigationTab> get _tabs => [
    const _NavigationTab(
      page: TriageFormPage(),
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
      label: 'Triage',
    ),
    const _NavigationTab(
      page: HistoryPage(),
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      label: 'Historial',
    ),
    if (widget.profile.role == UserRole.admin)
      const _NavigationTab(
        page: AcademicDashboardPage(),
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        label: 'Métricas IA',
      ),
    // Future administrator tabs can be appended here.
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [for (final tab in tabs) tab.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.2),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon, color: AppColors.primary),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _NavigationTab {
  final Widget page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavigationTab({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
