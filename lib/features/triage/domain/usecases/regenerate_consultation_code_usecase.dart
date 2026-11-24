import '../../data/datasources/assessment_remote_datasource.dart';
import '../../domain/entities/assessment_record.dart';
import '../repositories/assessment_repository.dart';

sealed class RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeSuccess
    extends RegenerateConsultationCodeResult {
  final String code;
  RegenerateConsultationCodeSuccess(this.code);
}

class RegenerateConsultationCodeNotAuthorized
    extends RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeNotFound
    extends RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeLimitReached
    extends RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeNoConnection
    extends RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeNotSynced
    extends RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeError
    extends RegenerateConsultationCodeResult {}

class RegenerateConsultationCodeUseCase {
  final AssessmentRepository repository;
  final AssessmentRemoteDataSource remoteDataSource;
  final Future<bool> Function() hasInternet;
  final bool Function() hasSession;

  const RegenerateConsultationCodeUseCase({
    required this.repository,
    required this.remoteDataSource,
    required this.hasInternet,
    required this.hasSession,
  });

  Future<RegenerateConsultationCodeResult> execute(
    String uuid, {
    SyncStatus? syncStatus,
  }) async {
    if (syncStatus != null && syncStatus != SyncStatus.synced) {
      return RegenerateConsultationCodeNotSynced();
    }
    if (!hasSession()) {
      return RegenerateConsultationCodeNotAuthorized();
    }
    if (!await hasInternet()) {
      return RegenerateConsultationCodeNoConnection();
    }

    try {
      final response = await remoteDataSource.regenerateConsultationCode(uuid);
      if (response['ok'] == true) {
        final code = response['codigo'];
        if (code is! String || code.replaceAll('-', '').length != 8) {
          return RegenerateConsultationCodeError();
        }
        final normalized = code.replaceAll('-', '').toUpperCase();
        if (syncStatus == SyncStatus.synced) {
          await repository.updateConsultationCode(uuid: uuid, code: normalized);
        }
        return RegenerateConsultationCodeSuccess(normalized);
      }
      switch (response['motivo']) {
        case 'no_autorizado':
          return RegenerateConsultationCodeNotAuthorized();
        case 'no_encontrado':
          return RegenerateConsultationCodeNotFound();
        case 'limite':
          return RegenerateConsultationCodeLimitReached();
        default:
          return RegenerateConsultationCodeError();
      }
    } catch (error) {
      if (remoteDataSource.isNetworkFailure(error)) {
        return RegenerateConsultationCodeNoConnection();
      }
      return RegenerateConsultationCodeError();
    }
  }
}
