import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/entities/user.dart';
import 'package:puzzgame_flutter/core/infrastructure/service_locator.dart';
import 'package:puzzgame_flutter/core/domain/services/auth_service.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

class UserProfileWidget extends StatelessWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = serviceLocator<AuthService>();
    
    return StreamBuilder<AppUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        if (user == null) {
          // Show sign-in prompt when not authenticated
          return CozyPuzzleTheme.createThemedContainer(
            isPrimary: false,
            child: Column(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 48,
                  color: CozyPuzzleTheme.stoneGray,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to save your progress',
                  style: CozyPuzzleTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                CozyPuzzleTheme.createThemedButton(
                  text: 'Sign In',
                  onPressed: () {
                    Navigator.pushNamed(context, '/sign-in');
                  },
                  icon: Icons.login,
                  isPrimary: true,
                ),
              ],
            ),
          );
        }
        
        return CozyPuzzleTheme.createThemedContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with avatar and name
              Row(
                children: [
                  // User avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: CozyPuzzleTheme.goldenSandbar,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: CozyPuzzleTheme.deepSlate.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.email.substring(0, 1).toUpperCase(),
                        style: CozyPuzzleTheme.headingMedium.copyWith(
                          color: CozyPuzzleTheme.deepSlate,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: CozyPuzzleTheme.labelLarge.copyWith(
                            color: CozyPuzzleTheme.stoneGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: CozyPuzzleTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: CozyPuzzleTheme.seafoamMist.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CozyPuzzleTheme.seafoamMist,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: CozyPuzzleTheme.seafoamMist,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: CozyPuzzleTheme.labelSmall.copyWith(
                            color: CozyPuzzleTheme.deepSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Account actions
              Row(
                children: [
                  Expanded(
                    child: CozyPuzzleTheme.createThemedButton(
                      text: 'Profile',
                      onPressed: () {
                        // TODO: Navigate to profile screen when implemented
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Profile screen coming soon!',
                              style: CozyPuzzleTheme.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: CozyPuzzleTheme.seafoamMist,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: Icons.person,
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CozyPuzzleTheme.createThemedButton(
                      text: 'Sign Out',
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: CozyPuzzleTheme.linenWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              'Sign Out',
                              style: CozyPuzzleTheme.headingSmall,
                            ),
                            content: Text(
                              'Are you sure you want to sign out? Your progress will be saved.',
                              style: CozyPuzzleTheme.bodyMedium,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              CozyPuzzleTheme.createThemedButton(
                                text: 'Sign Out',
                                onPressed: () => Navigator.of(context).pop(true),
                                isAlert: true,
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmed == true) {
                          await authService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        }
                      },
                      icon: Icons.logout,
                      isAlert: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
