import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Full screen
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Hive init
  await Hive.initFlutter();

  runApp(const ProviderScope(child: BroadcasterApp()));
}

class BroadcasterApp extends ConsumerWidget {
  const BroadcasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TikTok LIVE OBS - Broadcaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFE2C55),
          secondary: const Color(0xFF25F4EE),
          surface: const Color(0xFF161823),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161823),
          elevation: 0,
        ),
      ),
      routerConfig: router,
    );
  }
}
