import 'package:puzzgame_flutter/core/domain/entities/user.dart';

abstract class AuthService {
  /// Sign in with Google
  Future<AppUser?> signInWithGoogle();
  
  /// Sign out the current user
  Future<void> signOut();
  
  /// Get the current user
  AppUser? get currentUser;
  
  /// Stream of auth state changes
  Stream<AppUser?> get authStateChanges;
}
