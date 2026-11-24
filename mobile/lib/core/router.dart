import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/card/card_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/records/record_kind.dart';
import '../features/records/record_list_screen.dart';
import '../features/reports/report_detail_screen.dart';
import '../features/reports/reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect when the user logs in or out. Only the kind of state
  // matters: refreshing on every record update (e.g. after saving the
  // profile) would re-open the screen the user just closed.
  final authChanged = ValueNotifier<int>(0);
  ref.listen(
    authControllerProvider.select((state) => state.runtimeType),
    (_, __) => authChanged.value++,
  );
  ref.onDispose(authChanged.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanged,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/signup';
      return switch (ref.read(authControllerProvider)) {
        SignedIn() => onAuthPage || location == '/splash' ? '/' : null,
        SignedOut() => onAuthPage ? null : '/login',
        AuthLoading() ||
        AuthUnavailable() => location == '/splash' ? null : '/splash',
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/card', builder: (_, __) => const CardScreen()),
      GoRoute(
        path: '/records/:slug',
        builder:
            (_, state) => RecordListScreen(
              kind: recordKindBySlug(state.pathParameters['slug']!),
            ),
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(
        path: '/reports/:id',
        builder:
            (_, state) =>
                ReportDetailScreen(reportId: state.pathParameters['id']!),
      ),
    ],
  );
});
