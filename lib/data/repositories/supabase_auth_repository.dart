import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/data/models/user_model.dart';
import 'package:polyfind/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  UserModel? _currentUser;

  @override
  Stream<UserModel?> get authStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user == null) {
        _currentUser = null;
        return null;
      }
      _currentUser = await _loadProfile(user);
      return _currentUser;
    });
  }

  @override
  UserModel? get currentUser => _currentUser;

  Future<UserModel> _loadProfile(User user) async {
    final profile =
        await _client.from('profiles').select().eq('id', user.id).single();
    return UserModel.fromProfile(profile, email: user.email ?? '');
  }

  @override
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String admissionNumber,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.endsWith(AppConstants.schoolEmailDomain)) {
      throw AuthRepositoryException(
        'Use your school email (${AppConstants.schoolEmailDomain}).',
      );
    }

    try {
      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'name': name.trim(),
          'admission_number': admissionNumber.trim(),
        },
      );
      final user = response.user;
      if (user == null) {
        throw const AuthRepositoryException(
          'Supabase did not return a user after registration.',
        );
      }
      if (response.session == null) {
        _currentUser = null;
        return null;
      }

      _currentUser = await _loadProfile(user);
      return _currentUser!;
    } on AuthRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw AuthRepositoryException(_profileErrorMessage(error));
    } on AuthException catch (error) {
      throw AuthRepositoryException(_authErrorMessage(error));
    }
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthRepositoryException('Could not sign in.');
      }

      _currentUser = await _loadProfile(user);
      return _currentUser!;
    } on AuthRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw AuthRepositoryException(_profileErrorMessage(error));
    } on AuthException catch (error) {
      throw AuthRepositoryException(_authErrorMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _currentUser = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on AuthException catch (error) {
      throw AuthRepositoryException(_authErrorMessage(error));
    }
  }

  @override
  Future<UserModel> updateProfile({String? name}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthRepositoryException('No user is signed in.');
    }

    if (name != null) {
      await _client.from('profiles').update({'name': name.trim()}).eq(
        'id',
        user.id,
      );
    }
    _currentUser = await _loadProfile(user);
    return _currentUser!;
  }

  String _authErrorMessage(AuthException error) {
    final message = switch (error.code) {
      'weak_password' => 'Choose a stronger password.',
      'email_exists' => 'An account already exists for this email.',
      'invalid_credentials' => 'Check your email and password.',
      'user_not_found' => 'No account was found with this email.',
      'email_not_confirmed' => 'Confirm your email address before signing in.',
      'over_email_send_rate_limit' => 'Too many attempts. Try again later.',
      _ => error.message,
    };
    return '$message (auth/${error.code ?? 'error'})';
  }

  String _profileErrorMessage(PostgrestException error) {
    if (error.code == 'PGRST116') {
      return 'Your account exists, but its profile was not created. '
          'Run supabase/schema.sql in the Supabase SQL Editor, then try again.';
    }
    return 'Signed in, but could not load your profile. '
        'Check the profiles table and its SELECT policy in Supabase '
        '(${error.code ?? 'database error'}).';
  }
}
