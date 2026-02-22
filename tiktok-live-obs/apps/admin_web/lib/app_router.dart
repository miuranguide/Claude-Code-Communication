import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/admin_auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/users_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/logs_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(adminAuthProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = auth.isLoggedIn;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
      GoRoute(path: '/devices', builder: (_, __) => const DevicesScreen()),
      GoRoute(path: '/logs', builder: (_, __) => const LogsScreen()),
    ],
  );
});
