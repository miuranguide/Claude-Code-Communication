import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pair_screen.dart';
import 'screens/control_screen.dart';
import 'screens/assign_screen.dart';
import 'screens/message_list_screen.dart';
import 'screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/pair', builder: (_, __) => const PairScreen()),
      GoRoute(path: '/control', builder: (_, __) => const ControlScreen()),
      GoRoute(path: '/assign', builder: (_, __) => const AssignScreen()),
      GoRoute(path: '/messages', builder: (_, __) => const MessageListScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
