import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class GetCurrentProfileUseCase {
  final AuthRepository repository;

  GetCurrentProfileUseCase(this.repository);

  Future<UserProfile?> execute() => repository.getCurrentProfile();
}
