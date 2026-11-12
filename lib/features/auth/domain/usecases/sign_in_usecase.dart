import '../entities/user_profile.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  final AuthRepository repository;

  SignInUseCase(this.repository);

  Future<UserProfile> execute(String email, String password) {
    return repository.signIn(email, password);
  }
}
