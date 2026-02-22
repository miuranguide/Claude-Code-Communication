import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/assets_screen.dart';
import 'screens/layout_editor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/message_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/assets', builder: (_, __) => const AssetsScreen()),
      GoRoute(
        path: '/layout/:clipId',
        builder: (_, state) => LayoutEditorScreen(
          clipId: state.pathParameters['clipId']!,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/messages', builder: (_, __) => const MessageListScreen()),
    ],
  );
});
