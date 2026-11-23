import 'package:polyfind/data/models/user_model.dart';

abstract class AuthRepository {
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String admissionNumber,
  });

  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<UserModel> updateProfile({
    String? name,
  });
}
