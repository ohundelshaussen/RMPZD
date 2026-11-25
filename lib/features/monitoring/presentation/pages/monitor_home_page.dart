import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/monitoring_case.dart';
import '../providers/monitoring_provider.dart';
import 'monitoring_case_detail_page.dart';

class MonitorHomePage extends StatefulWidget {
  const MonitorHomePage({super.key});

  @override
  State<MonitorHomePage> createState() => _MonitorHomePageState();
}

class _MonitorHomePageState extends State<MonitorHomePage> {
  StreamSubscription<MonitoringAlert>? _alertsSubscription;
  StreamSubscription<String>? _caseOpenSubscription;
  Timer? _bannerTimer;
  MonitoringAlert? _bannerAlert;
  String? _openingCaseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MonitoringProvider>();
      _alertsSubscription = provider.alerts.listen(_showBanner);
      _caseOpenSubscription = provider.caseOpenRequests.listen(_openCase);
      final pendingCaseId = provider.takePendingCaseId();
      if (pendingCaseId != null) _openCase(pendingCaseId);
    });
  }

  void _showBanner(MonitoringAlert alert) {
    if (!mounted) return;
    _bannerTimer?.cancel();
    setState(() => _bannerAlert = alert);
    HapticFeedback.vibrate();
    _bannerTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _bannerAlert = null);
    });
  }

  void _openCase(String caseId) {
    if (!mounted || _openingCaseId == caseId) return;
    _openingCaseId = caseId;
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => MonitoringCaseDetailPage(caseId: caseId),
          ),
        )
        .whenComplete(() {
          if (_openingCaseId == caseId) _openingCaseId = null;
        });
  }

  void _openBannerCase() {
    final caseId = _bannerAlert?.caseId;
    _bannerTimer?.cancel();
    setState(() => _bannerAlert = null);
    if (caseId != null) _openCase(caseId);
  }

  Future<void> _signOut() async {
    try {
      await context.read<AuthProvider>().signOut();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final provider = context.watch<MonitoringProvider>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile?.displayName ?? 'Monitor'),
              Text(
                UserRole.monitor.label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: provider.isConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(provider.isConnected ? 'En vivo' : 'Reconectando…'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nuevos'),
                    if (provider.newCasesCount > 0) ...[
                      const SizedBox(width: 6),
                      _CountBadge(count: provider.newCasesCount),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Mis casos'),
              const Tab(text: 'Cerrados'),
            ],
          ),
        ),
        body: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _bannerAlert == null
                  ? const SizedBox.shrink(key: ValueKey('no-alert'))
                  : _AlertBanner(
                      key: ValueKey(_bannerAlert!.caseId),
                      alert: _bannerAlert!,
                      onTap: _openBannerCase,
                      onDismiss: () {
                        _bannerTimer?.cancel();
                        setState(() => _bannerAlert = null);
                      },
                    ),
            ),
            if (provider.notificationErrorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  provider.notificationErrorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _MonitoringCaseList(status: MonitoringCaseStatus.nuevo),
                  _MonitoringCaseList(status: MonitoringCaseStatus.enGestion),
                  _MonitoringCaseList(status: MonitoringCaseStatus.cerrado),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _alertsSubscription?.cancel();
    _caseOpenSubscription?.cancel();
    super.dispose();
  }
}

class _MonitoringCaseList extends StatefulWidget {
  final MonitoringCaseStatus status;

  const _MonitoringCaseList({required this.status});

  @override
  State<_MonitoringCaseList> createState() => _MonitoringCaseListState();
}

class _MonitoringCaseListState extends State<_MonitoringCaseList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 300) {
      return;
    }
    context.read<MonitoringProvider>().loadMore(widget.status);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MonitoringProvider>();
    final cases = provider.casesFor(widget.status);
    final hasMore = switch (widget.status) {
      MonitoringCaseStatus.nuevo => provider.newCasesHaveMore,
      MonitoringCaseStatus.enGestion => provider.myCasesHaveMore,
      MonitoringCaseStatus.cerrado => false,
    };
    final loadingMore = switch (widget.status) {
      MonitoringCaseStatus.nuevo => provider.loadingMoreNew,
      MonitoringCaseStatus.enGestion => provider.loadingMoreMine,
      MonitoringCaseStatus.cerrado => false,
    };
    final showLoader = loadingMore || hasMore;

    return RefreshIndicator(
      onRefresh: provider.refreshLists,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (cases.isEmpty && provider.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (cases.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No hay casos en esta pestaña.')),
              ),
            )
          else
            for (final item in cases)
              MonitoringCaseCard(
                item: item,
                isNewCase: widget.status == MonitoringCaseStatus.nuevo,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => MonitoringCaseDetailPage(caseId: item.id),
                  ),
                ),
              ),
          if (showLoader)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }
}

class MonitoringCaseCard extends StatefulWidget {
  final MonitoringCase item;
  final bool isNewCase;
  final DateTime Function() currentTime;
  final VoidCallback? onTap;

  const MonitoringCaseCard({
    required this.item,
    required this.isNewCase,
    this.currentTime = DateTime.now,
    this.onTap,
    super.key,
  });

  @override
  State<MonitoringCaseCard> createState() => _MonitoringCaseCardState();
}

class _MonitoringCaseCardState extends State<MonitoringCaseCard> {
  Timer? _elapsedTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.currentTime();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = widget.currentTime());
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final critical = item.priority == MonitoringPriority.critica;
    final elapsed = _now.difference(item.createdAt);
    final unattended =
        widget.isNewCase && elapsed >= const Duration(minutes: 10);
    final colorScheme = Theme.of(context).colorScheme;
    final priorityColor = critical ? colorScheme.error : Colors.deepOrange;
    final location = [
      item.municipality ?? 'Municipio sin registrar',
      item.department ?? 'Departamento sin registrar',
    ].join(', ');
    final patient = [
      if (item.patientName != null) item.patientName!,
      if (item.patientId != null) 'ID: ${item.patientId}',
    ].join(' · ');

    return Card(
      color: unattended ? colorScheme.errorContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    critical ? Icons.emergency_rounded : Icons.warning_rounded,
                    color: priorityColor,
                    size: 22,
                  ),
                  Text(
                    critical ? 'Prioridad crítica' : 'Alto riesgo',
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (unattended)
                    Chip(
                      avatar: Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 18,
                      ),
                      label: const Text('Sin atender'),
                      backgroundColor: colorScheme.errorContainer,
                      side: BorderSide(color: colorScheme.error),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(location, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                patient.isEmpty
                    ? 'Paciente sin datos identificatorios'
                    : patient,
              ),
              const SizedBox(height: 4),
              Text(
                'Gestación: ${item.gestationWeeks == null ? 'Sin dato' : '${item.gestationWeeks} semanas'}',
              ),
              const SizedBox(height: 6),
              Text(_elapsedLabel(elapsed)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }
}

class _AlertBanner extends StatelessWidget {
  final MonitoringAlert alert;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _AlertBanner({
    required this.alert,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final critical = alert.priority == MonitoringPriority.critica;
    final colorScheme = Theme.of(context).colorScheme;
    final background = critical
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final foreground = critical
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                critical ? Icons.emergency_rounded : Icons.warning_rounded,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nueva ${alert.title.toLowerCase()} · Ver caso',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Descartar alerta',
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onError,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _elapsedLabel(Duration elapsed) {
  if (elapsed.inDays > 0) {
    return 'Hace ${elapsed.inDays} ${elapsed.inDays == 1 ? 'día' : 'días'}';
  }
  if (elapsed.inHours > 0) {
    return 'Hace ${elapsed.inHours} h';
  }
  if (elapsed.inMinutes > 0) {
    return 'Hace ${elapsed.inMinutes} min';
  }
  return 'Hace menos de 1 min';
}
