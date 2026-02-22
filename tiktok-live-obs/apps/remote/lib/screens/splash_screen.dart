import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import '../services/ws_client.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      // Try auto-reconnect with saved connection info
      final wsClient = ref.read(wsClientProvider.notifier);
      final ok = await wsClient.tryAutoReconnect();
      if (!mounted) return;
      if (ok) {
        context.go('/control');
      } else {
        context.go('/pair');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 20),
              const Text(
                'Controller',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppConstants.versionDisplay,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
