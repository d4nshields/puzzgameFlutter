import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService implements AuthService {
  final _client = SupabaseConfig.client;
  final _googleSignIn = GoogleSignIn(
    // Add your web client ID here if you have one configured
    // This is optional for Android but required for iOS
    // clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
  );
  
  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      // Native Google Sign In (for mobile)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled the sign-in
          return null;
        }
        
        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;
        
        if (idToken == null || accessToken == null) {
          throw Exception('No ID token or access token received from Google');
        }
        
        final response = await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        
        return _mapSupabaseUserToAppUser(response.user);
      } else {
        // Web OAuth flow
        final response = await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.puzzgame://login-callback/',
        );
        
        if (!response) {
          throw Exception('Failed to sign in with Google');
        }
        
        // Wait for the auth state to update
        await Future.delayed(const Duration(seconds: 1));
        
        final user = _client.auth.currentUser;
        return _mapSupabaseUserToAppUser(user);
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _client.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  @override
  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    return _mapSupabaseUserToAppUser(user);
  }
  
  @override
  Stream<AppUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((data) {
      return _mapSupabaseUserToAppUser(data.session?.user);
    });
  }
  
  AppUser? _mapSupabaseUserToAppUser(User? user) {
    if (user == null) return null;
    
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      username: user.userMetadata?['username'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      createdAt: DateTime.parse(user.createdAt),
      profileData: user.userMetadata ?? {},
    );
  }
}
