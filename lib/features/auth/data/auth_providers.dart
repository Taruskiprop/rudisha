import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:polyfind/data/repositories/auth_repository.dart';
import 'package:polyfind/data/repositories/supabase_auth_repository.dart';
import 'package:polyfind/data/models/user_model.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return SupabaseAuthRepository();
}

@riverpod
Stream<UserModel?> authStateChanges(AuthStateChangesRef ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
}

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<UserModel?> build() {
    return null;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String admissionNumber,
  }) async {
    if (state is AsyncLoading) return false;

    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            name: name,
            admissionNumber: admissionNumber,
          );
      if (state is AsyncLoading) state = AsyncData(user);
      return user != null;
    } catch (error, stackTrace) {
      if (state is AsyncLoading) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (state is AsyncLoading) return;

    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signIn(
        email: email,
        password: password,
      );
      if (state is AsyncLoading) {
        state = AsyncData(user);
      }
    } catch (e, st) {
      if (state is AsyncLoading) {
        state = AsyncError(e, st);
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendPasswordResetEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? name,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.updateProfile(
        name: name,
      );
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
