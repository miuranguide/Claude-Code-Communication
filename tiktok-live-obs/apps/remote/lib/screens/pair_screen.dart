import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/ws_client.dart';

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  bool _scanning = false;
  bool _connecting = false;
  String? _error;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _tryAutoReconnect();
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  void _setError(String msg) {
    _errorTimer?.cancel();
    setState(() => _error = msg);
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _error = null);
    });
  }

  Future<void> _tryAutoReconnect() async {
    final wsClient = ref.read(wsClientProvider.notifier);
    if (await wsClient.hasSavedConnection) {
      setState(() => _connecting = true);
      final ok = await wsClient.tryAutoReconnect();
      if (ok && mounted) {
        context.go('/control');
      } else {
        if (mounted) setState(() => _connecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_android,
                  size: 56, color: Colors.white54),
              const SizedBox(height: 16),
              const Text('TikTok LIVE Remote',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Broadcasterに表示されたQRコードを\nスキャンして接続',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.redAccent.withAlpha(76)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
                const SizedBox(height: 16),
              ],
              if (_connecting)
                const Column(
                  children: [
                    CircularProgressIndicator(
                        color: Color(0xFFFE2C55)),
                    SizedBox(height: 12),
                    Text('接続中...',
                        style: TextStyle(color: Colors.white54)),
                  ],
                )
              else if (_scanning)
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      onDetect: _onQrDetected,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => _scanning = true),
                        icon: const Icon(Icons.qr_code_scanner,
                            size: 24),
                        label: const Text('QRスキャン',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFE2C55),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _showManualInput(),
                      child: const Text('手動入力',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_connecting) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() {
      _scanning = false;
      _connecting = true;
      _error = null;
    });

    try {
      final data = jsonDecode(code);
      if (data is! Map<String, dynamic>) {
        setState(() => _connecting = false);
        _setError('QRコードが無効です');
        return;
      }
      final wsUrl = data['wsUrl'] as String?;
      final token = data['token'] as String?;
      final name = data['name'] as String?;

      if (wsUrl == null || token == null) {
        setState(() => _connecting = false);
        _setError('QRコードにURLまたはトークンがありません');
        return;
      }

      final ok = await ref.read(wsClientProvider.notifier).connect(
            wsUrl,
            token,
            name: name,
          );

      if (ok && mounted) {
        context.go('/control');
      } else {
        setState(() => _connecting = false);
        _setError('接続に失敗しました');
      }
    } catch (e) {
      setState(() => _connecting = false);
      _setError('QRコードが無効です');
    }
  }

  void _showManualInput() {
    final urlCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('手動接続', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'WebSocket URL',
                hintText: 'ws://192.168.x.x:9876',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Token',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              urlCtrl.dispose();
              tokenCtrl.dispose();
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              final token = tokenCtrl.text.trim();
              Navigator.pop(dialogContext);
              urlCtrl.dispose();
              tokenCtrl.dispose();

              if (url.isEmpty || token.isEmpty) {
                _setError('URLとトークンを入力してください');
                return;
              }
              if (!url.startsWith('ws://') &&
                  !url.startsWith('wss://')) {
                _setError('URLはws://またはwss://で始まる必要があります');
                return;
              }

              setState(() => _connecting = true);
              final ok = await ref
                  .read(wsClientProvider.notifier)
                  .connect(url, token);
              if (ok && mounted) {
                context.go('/control');
              } else {
                setState(() => _connecting = false);
                _setError('接続に失敗しました');
              }
            },
            child: const Text('接続'),
          ),
        ],
      ),
    );
  }
}
