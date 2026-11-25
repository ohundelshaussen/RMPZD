import 'package:flutter/material.dart';

class MonitoringCaseDetailPage extends StatelessWidget {
  final String caseId;

  const MonitoringCaseDetailPage({required this.caseId, super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle del caso')),
    body: Center(child: Text('Caso: $caseId')),
  );
}
