import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/core/infrastructure/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService implements AuthService {
  final _client = SupabaseConfig.client;
  
  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In with Supabase native OAuth...');
      print('Platform: Android=${Platform.isAndroid}, iOS=${Platform.isIOS}, Web=${kIsWeb}');
      
      // Create a completer to wait for auth state change
      final completer = Completer<AppUser?>();
      late StreamSubscription authSubscription;
      
      // Listen for auth state changes
      authSubscription = _client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;
        
        print('Auth state changed: $event');
        
        if (event == AuthChangeEvent.signedIn && session != null) {
          print('User signed in successfully: ${session.user.email}');
          authSubscription.cancel();
          completer.complete(_mapSupabaseUserToAppUser(session.user));
        } else if (event == AuthChangeEvent.signedOut) {
          print('User signed out');
          authSubscription.cancel();
          completer.complete(null);
        }
      });
      
      // Start the OAuth flow
      bool success;
      
      if (kIsWeb) {
        // Web OAuth flow
        success = await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: null, // Use default web redirect
        );
      } else {
        // Mobile OAuth flow (Android/iOS)
        success = await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.puzzgame://login-callback/',
        );
      }
      
      if (!success) {
        authSubscription.cancel();
        throw Exception('Failed to initiate Google Sign-In');
      }
      
      print('OAuth flow initiated successfully, waiting for completion...');
      
      // Wait for auth state change or timeout
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          authSubscription.cancel();
          throw Exception('Google Sign-In timed out');
        },
      );
      
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');
      if (e is AuthException) {
        print('Auth exception details:');
        print('- Message: ${e.message}');
        print('- Status Code: ${e.statusCode}');
      }
      rethrow;
    }
  }
  
  @override
  Future<void> signOut() async {
    try {
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
