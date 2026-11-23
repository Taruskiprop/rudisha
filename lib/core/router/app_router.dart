import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/features/auth/data/auth_providers.dart';
import 'package:polyfind/features/auth/presentation/screens/auth_screen.dart';
import 'package:polyfind/features/auth/presentation/screens/login_screen.dart';
import 'package:polyfind/features/auth/presentation/screens/register_screen.dart';
import 'package:polyfind/features/home/presentation/screens/home_screen.dart';
import 'package:polyfind/features/items/presentation/screens/post_item_screen.dart';
import 'package:polyfind/features/items/presentation/screens/item_detail_screen.dart';
import 'package:polyfind/features/profile/presentation/screens/profile_screen.dart';
import 'package:polyfind/features/profile/presentation/screens/my_activity_screen.dart';
import 'package:polyfind/features/admin/presentation/screens/admin_screen.dart';
import 'package:polyfind/features/claims/presentation/screens/claims_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final router = GoRouter(
    initialLocation: AppConstants.routeSplash,
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      final controllerUser = ref.read(authControllerProvider).asData?.value;
      final user = controllerUser ?? authState.asData?.value;
      final isLoggingIn =
          state.matchedLocation.startsWith(AppConstants.routeAuth);
      final isOnSplash = state.matchedLocation == AppConstants.routeSplash;

      if (user != null) {
        debugPrint(
            'Router redirect: user=${user.email}, location=${state.matchedLocation}, isOnSplash=$isOnSplash, isLoggingIn=$isLoggingIn');
        return isOnSplash || isLoggingIn ? AppConstants.routeHome : null;
      }

      return authState.when(
        data: (_) {
          debugPrint(
              'Router redirect: no authenticated user, location=${state.matchedLocation}, isOnSplash=$isOnSplash, isLoggingIn=$isLoggingIn');
          return isLoggingIn ? null : AppConstants.routeAuth;
        },
        loading: () {
          debugPrint('Router redirect: loading');
          return null;
        },
        error: (e, st) {
          debugPrint('Router redirect error: $e');
          return AppConstants.routeAuth;
        },
      );
    },
    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.routeAuth,
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
        routes: [
          GoRoute(
            path: 'login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'register',
            name: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppConstants.routeHome,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppConstants.routePostItem,
        name: 'postItem',
        builder: (context, state) => const PostItemScreen(),
      ),
      GoRoute(
        path: AppConstants.routeItemDetail,
        name: 'itemDetail',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return ItemDetailScreen(itemId: itemId);
        },
      ),
      GoRoute(
        path: AppConstants.routeMyActivity,
        name: 'myActivity',
        builder: (context, state) => const MyActivityScreen(),
      ),
      GoRoute(
        path: AppConstants.routeProfile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppConstants.routeClaims,
        name: 'claims',
        builder: (context, state) => const ClaimsScreen(),
      ),
      GoRoute(
        path: AppConstants.routeAdmin,
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.routeHome),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );

  ref.listen(authStateChangesProvider, (_, __) => router.refresh());
  ref.listen(authControllerProvider, (_, __) => router.refresh());
  ref.onDispose(router.dispose);

  return router;
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.search_outlined,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
