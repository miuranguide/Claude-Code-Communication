import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final id = _idCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (id.isEmpty || pass.isEmpty) return;

    final ok = await ref.read(authProvider.notifier).login(id, pass);
    if (ok && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5FE),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF3E0), // warm orange-white
              Color(0xFFFFE0EC), // warm pink-white
              Color(0xFFE8F5FE), // light cyan
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 50),

                // Logo
                Image.asset(
                  'assets/logo.png',
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Display',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black38,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 32),

                // Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.black38),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ラクガキ企画所属者のみ利用可能です。\nログインIDは管理者から発行されます。',
                          style: TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Login ID
                TextField(
                  controller: _idCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'ログインID',
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.black45),
                    filled: true,
                    fillColor: Colors.white.withAlpha(200),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Password
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.black45),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black38,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(200),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 20),

                // Error
                if (auth.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.redAccent.withAlpha(75)),
                    ),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFE2C55),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFFFE2C55).withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ログイン',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'パスワードについて',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '- 初期パスワードはログインIDと同じです\n'
                        '- 6文字以上（英数字・記号使用可）\n'
                        '- 大文字・小文字の区別あり\n'
                        '- ログイン後、設定画面からパスワード変更できます',
                        style: TextStyle(fontSize: 10, color: Colors.black45, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  AppConstants.versionDisplay,
                  style: const TextStyle(fontSize: 10, color: Colors.black26),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
