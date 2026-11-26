class DoctorMonitoringCase {
  final String state;
  final String? result;
  final DateTime? closedAt;

  const DoctorMonitoringCase({required this.state, this.result, this.closedAt});

  bool get isOpen => state == 'nuevo' || state == 'en_gestion';
  bool get isClosed => state == 'cerrado';
}

class DoctorReferralResult {
  final bool ok;
  final String? motive;
  final bool reopened;
  final String? state;

  const DoctorReferralResult({
    required this.ok,
    this.motive,
    this.reopened = false,
    this.state,
  });
}
