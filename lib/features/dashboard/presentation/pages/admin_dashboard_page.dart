import 'package:flutter/material.dart';

import 'academic_dashboard_page.dart';
import '../widgets/dashboard_operation_view.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Operación'),
              Tab(text: 'Modelo (Fase 2)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DashboardOperationView(),
            AcademicDashboardBody(),
          ],
        ),
      ),
    );
  }
}
