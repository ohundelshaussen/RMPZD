import '../entities/patient_record_view.dart';

sealed class LookupPatientRecordsResult {
  const LookupPatientRecordsResult();
}

class PatientRecordFound extends LookupPatientRecordsResult {
  final PatientRecordView record;

  const PatientRecordFound(this.record);
}

class PatientRecordsNotFound extends LookupPatientRecordsResult {
  const PatientRecordsNotFound();
}

class PatientLookupBlocked extends LookupPatientRecordsResult {
  const PatientLookupBlocked();
}

class PatientLookupIncomplete extends LookupPatientRecordsResult {
  const PatientLookupIncomplete();
}

class PatientLookupNoConnection extends LookupPatientRecordsResult {
  const PatientLookupNoConnection();
}

class PatientLookupError extends LookupPatientRecordsResult {
  const PatientLookupError();
}

abstract interface class PatientRecordsLookup {
  Future<LookupPatientRecordsResult> lookup({
    required String document,
    required String code,
  });
}

class LookupPatientRecordsUseCase {
  final PatientRecordsLookup dataSource;

  const LookupPatientRecordsUseCase(this.dataSource);

  Future<LookupPatientRecordsResult> execute({
    required String document,
    required String code,
  }) => dataSource.lookup(document: document, code: code);
}
