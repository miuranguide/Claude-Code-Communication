import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/playback_provider.dart';
import '../providers/server_provider.dart';
import '../services/ws_server.dart';
import '../widgets/overlay_layer.dart';
import '../widgets/bgm_player.dart';
import '../widgets/message_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  bool _cameraInitializing = true;
  String? _cameraError;
  bool _useFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
    // Start WS server
    Future.microtask(() {
      ref.read(wsServerProvider.notifier).start();
    });
  }

  Future<void> _initCamera() async {
    setState(() {
      _cameraInitializing = true;
      _cameraError = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _cameraInitializing = false;
            _cameraError = 'カメラ権限が必要です';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('カメラ権限を許可してください'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraInitializing = false;
            _cameraError = 'カメラが見つかりません';
          });
        }
        return;
      }

      final targetDirection = _useFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == targetDirection,
        orElse: () => cameras.first,
      );

      _cameraCtrl?.dispose();
      _cameraCtrl = CameraController(camera, ResolutionPreset.high);
      await _cameraCtrl!.initialize();
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _cameraInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraError = 'カメラの初期化に失敗しました';
        });
      }
    }
  }

  void _switchCamera() {
    setState(() {
      _useFrontCamera = !_useFrontCamera;
      _cameraReady = false;
    });
    _initCamera();
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final server = ref.watch(wsServerProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraReady && _cameraCtrl != null)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraCtrl!.value.previewSize?.height ?? 1080,
                  height: _cameraCtrl!.value.previewSize?.width ?? 1920,
                  child: CameraPreview(_cameraCtrl!),
                ),
              ),
            )
          else if (_cameraInitializing)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFE2C55)),
                    SizedBox(height: 12),
                    Text('カメラ起動中...',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_cameraError != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off,
                        color: Colors.white24, size: 48),
                    const SizedBox(height: 12),
                    Text(_cameraError!,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _initCamera,
                      child: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(color: Colors.black),

          // Video overlay
          if (playback.isPlaying && playback.activeClip != null)
            OverlayLayer(clip: playback.activeClip!),

          // BGM player (invisible)
          const BgmPlayer(),

          // Server error banner
          if (server.error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(229),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  server.error!,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Message bar (top)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: MessageBar(
              onTap: () => context.push('/messages'),
            ),
          ),

          // Top bar (below message bar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 36,
            left: 12,
            right: 12,
            child: _buildTopBar(server, playback),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 12,
            right: 12,
            child: _buildBottomBar(context, playback),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(WsServerState server, PlaybackState playback) {
    return Row(
      children: [
        // LIVE badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFE2C55),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('LIVE',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1)),
        ),
        const SizedBox(width: 8),
        // Connection status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color:
                    server.connectedClients > 0 ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                server.connectedClients > 0 ? 'Remote接続中' : '未接続',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Camera switch button
        _iconButton(Icons.cameraswitch, _switchCamera),
        const SizedBox(width: 8),
        // QR button
        _iconButton(Icons.qr_code, () => _showQrDialog()),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, PlaybackState playback) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Queue indicator
        if (playback.queueLength > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'キュー: ${playback.queueLength}件待ち',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
        // Playing indicator
        if (playback.isPlaying && playback.activeClip != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle,
                    color: Color(0xFFFE2C55), size: 18),
                const SizedBox(width: 6),
                Text(
                  playback.activeClip!.name,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        // Buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navButton(
                Icons.video_library, '素材', () => context.push('/assets')),
            _navButton(Icons.tune, '設定', () => context.push('/settings')),
            // STOP button (large, red)
            GestureDetector(
              onTap: () => ref.read(playbackProvider.notifier).stopAll(),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE2C55),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFE2C55).withAlpha(102),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('STOP',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final server = ref.watch(wsServerProvider);
          return AlertDialog(
            backgroundColor: const Color(0xFF1C2333),
            title: const Text('Remote接続', style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (server.isRunning && server.localIp != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: server.qrData,
                      size: 200,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    server.wsUrl,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Token: ${server.token.length >= 8 ? '${server.token.substring(0, 8)}...' : server.token}',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Remoteアプリでこのコードをスキャン',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ] else if (server.error != null) ...[
                  const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(server.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(wsServerProvider.notifier).start();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('再試行'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFE2C55),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  const CircularProgressIndicator(color: Color(0xFFFE2C55)),
                  const SizedBox(height: 12),
                  const Text('サーバー起動中...'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }
}
