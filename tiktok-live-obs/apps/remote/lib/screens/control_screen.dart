import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import '../services/ws_client.dart';
import '../providers/assign_provider.dart';
import '../widgets/message_bar.dart';

/// Button size preference provider (persisted in memory for now)
final bgmButtonSizeProvider = StateProvider<ButtonSizeMode>((ref) {
  return ButtonSizeMode.medium;
});

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(wsClientProvider);
    final assigns = ref.watch(assignProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Message bar (top, always visible)
            MessageBar(
              onTap: () => context.push('/messages'),
            ),

            // Reconnecting banner
            if (ws.connectionStatus == ConnectionStatus.reconnecting)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: Colors.orange.withAlpha(230),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '再接続中... (${ws.reconnectAttempt}/${AppConstants.maxReconnectAttempts}回目)',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref
                          .read(wsClientProvider.notifier)
                          .manualReconnect(),
                      child: const Text(
                        '手動再接続',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),

            // Error banner
            if (ws.connectionStatus == ConnectionStatus.error &&
                ws.lastError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: Colors.red.withAlpha(230),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ws.lastError!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref
                          .read(wsClientProvider.notifier)
                          .manualReconnect(),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.refresh,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

            // Top bar with QR always visible
            _buildTopBar(ws),

            // Tabs
            TabBar(
              controller: _tabCtrl,
              indicatorColor: const Color(0xFFFE2C55),
              tabs: const [
                Tab(text: '演出コントロール'),
                Tab(text: 'BGM'),
              ],
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildControlTab(ws, assigns),
                  _buildBgmTab(ws),
                ],
              ),
            ),

            // Preset toggle
            _buildPresetToggle(ws),

            // STOP button (always visible)
            _buildStopButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(WsClientState ws) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161823),
        border:
            Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: ws.connected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            ws.connected
                ? (ws.broadcasterName ?? 'Broadcaster')
                : '切断',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // ACK status
          if (ws.lastAckStatus != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ws.lastAckStatus == 'ok'
                    ? Colors.green.withAlpha(50)
                    : Colors.red.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ws.lastAckStatus == 'ok'
                    ? '送信成功'
                    : _formatAckError(ws.lastAckStatus!),
                style: TextStyle(
                  fontSize: 11,
                  color: ws.lastAckStatus == 'ok'
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          const SizedBox(width: 4),
          // Assign button
          IconButton(
            icon: const Icon(Icons.tune, size: 20),
            onPressed: () => context.push('/assign'),
            tooltip: 'ボタン割当',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () => context.push('/settings'),
            tooltip: '設定',
          ),
          // QR code button (always visible for re-pairing)
          IconButton(
            icon: const Icon(Icons.qr_code_scanner,
                size: 20, color: Color(0xFF25F4EE)),
            onPressed: () {
              ref.read(wsClientProvider.notifier).disconnect();
              context.go('/pair');
            },
            tooltip: 'QRスキャン（再ペアリング）',
          ),
        ],
      ),
    );
  }

  String _formatAckError(String status) {
    if (status.startsWith('error:')) {
      final code = status.substring(6);
      switch (code) {
        case WsError.cooldownActive:
          return 'CD中';
        case WsError.clipNotFound:
          return 'クリップなし';
        case WsError.trackNotFound:
          return 'BGMなし';
        default:
          return 'エラー';
      }
    }
    return 'エラー';
  }

  Widget _buildControlTab(
      WsClientState ws, AssignState assigns) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Vertical video buttons (9:16 ratio)
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 9.0 / 16.0, // Vertical video ratio
              children: [
                _verticalButton(
                  assigns.winLabel,
                  _clipName(ws, assigns.winClipId),
                  const Color(0xFF3fb950),
                  () => _sendClip(assigns.winClipId),
                  enabled:
                      ws.connected && assigns.winClipId != null,
                ),
                _verticalButton(
                  assigns.loseLabel,
                  _clipName(ws, assigns.loseClipId),
                  const Color(0xFFF85149),
                  () => _sendClip(assigns.loseClipId),
                  enabled:
                      ws.connected && assigns.loseClipId != null,
                ),
                _verticalButton(
                  assigns.other1Label,
                  _clipName(ws, assigns.other1ClipId),
                  const Color(0xFF58A6FF),
                  () => _sendClip(assigns.other1ClipId),
                  enabled: ws.connected &&
                      assigns.other1ClipId != null,
                ),
                _verticalButton(
                  assigns.other2Label,
                  _clipName(ws, assigns.other2ClipId),
                  const Color(0xFFBC8CFF),
                  () => _sendClip(assigns.other2ClipId),
                  enabled: ws.connected &&
                      assigns.other2ClipId != null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lookup clip name from ws state
  String? _clipName(WsClientState ws, String? clipId) {
    if (clipId == null) return null;
    for (final c in ws.clips) {
      if (c['id'] == clipId) return c['name'] as String?;
    }
    return null;
  }

  Widget _buildBgmTab(WsClientState ws) {
    final btnSize = ref.watch(bgmButtonSizeProvider);

    if (ws.tracks.isEmpty) {
      return const Center(
        child: Text('BGMが登録されていません',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return Column(
      children: [
        // Size toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('サイズ:',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
              const SizedBox(width: 8),
              for (final size in ButtonSizeMode.values) ...[
                GestureDetector(
                  onTap: () =>
                      ref.read(bgmButtonSizeProvider.notifier).state = size,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: btnSize == size
                          ? const Color(0xFF25F4EE).withAlpha(50)
                          : Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: btnSize == size
                            ? const Color(0xFF25F4EE)
                            : Colors.white12,
                      ),
                    ),
                    child: Text(
                      buttonSizeModeLabel(size),
                      style: TextStyle(
                        fontSize: 11,
                        color: btnSize == size
                            ? const Color(0xFF25F4EE)
                            : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ws.tracks.length,
            itemBuilder: (_, i) {
              final track = ws.tracks[i];
              final height = switch (btnSize) {
                ButtonSizeMode.large => 80.0,
                ButtonSizeMode.medium => 60.0,
                ButtonSizeMode.small => 44.0,
              };
              final fontSize = switch (btnSize) {
                ButtonSizeMode.large => 16.0,
                ButtonSizeMode.medium => 14.0,
                ButtonSizeMode.small => 12.0,
              };

              return Container(
                height: height,
                margin: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: const Color(0xFF161823),
                  child: InkWell(
                    onTap: ws.connected
                        ? () {
                            final id = track['id'];
                            if (id is String) _sendBgm(id);
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text('🎵',
                              style: TextStyle(fontSize: fontSize + 4)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              track['name'] as String? ?? 'BGM ${i + 1}',
                              style: TextStyle(fontSize: fontSize),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow,
                                color: Color(0xFF25F4EE)),
                            onPressed: ws.connected
                                ? () {
                                    final id = track['id'];
                                    if (id is String) _sendBgm(id);
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop,
                                color: Colors.white54),
                            onPressed:
                                ws.connected ? () => _stopBgm() : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPresetToggle(WsClientState ws) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('🔊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            _presetChip('バトル', 1.0, 0.3, ws),
            const SizedBox(width: 8),
            _presetChip('トーク', 0.6, 0.15, ws),
          ],
        ),
      ),
    );
  }

  String _activePreset = 'バトル';

  Widget _presetChip(String name, double clipGain,
      double bgmGain, WsClientState ws) {
    final isActive = _activePreset == name;
    return GestureDetector(
      onTap: ws.connected
          ? () {
              setState(() => _activePreset = name);
              ref
                  .read(wsClientProvider.notifier)
                  .send(WsCmd.setMix, {
                'name': name,
                'clipGain': clipGain,
                'bgmGain': bgmGain,
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFE2C55).withAlpha(50)
              : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFE2C55).withAlpha(125)
                : Colors.white12,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? const Color(0xFFFE2C55)
                : Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: () => _emergencyStop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFE2C55),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_circle, size: 28),
              SizedBox(width: 8),
              Text('STOP',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }

  /// Vertical video button (9:16 ratio)
  Widget _verticalButton(
    String label,
    String? clipName,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.heavyImpact();
              onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: enabled
              ? color.withAlpha(38)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? color.withAlpha(125)
                : Colors.white12,
            width: 2,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: color.withAlpha(50),
                      blurRadius: 12)
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large label area
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: enabled
                    ? color.withAlpha(25)
                    : Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enabled
                      ? color.withAlpha(50)
                      : Colors.white.withAlpha(12),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 36,
                  color: enabled
                      ? color.withAlpha(150)
                      : Colors.white.withAlpha(20),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label.isEmpty ? '名前未設定' : label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: label.isEmpty ? FontWeight.w400 : FontWeight.w800,
                  letterSpacing: label.isEmpty ? 0 : 1,
                  color: label.isEmpty
                      ? Colors.white.withAlpha(40)
                      : (enabled ? Colors.white : Colors.white24),
                ),
              ),
            ),
            if (clipName != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  clipName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: enabled
                        ? Colors.white54
                        : Colors.white12,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                '未設定',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withAlpha(30),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _sendClip(String? clipId) {
    if (clipId == null) return;
    ref
        .read(wsClientProvider.notifier)
        .send(WsCmd.playClip, {'clipId': clipId});
  }

  void _sendBgm(String trackId) {
    ref
        .read(wsClientProvider.notifier)
        .send(WsCmd.playBgm, {'trackId': trackId});
  }

  void _stopBgm() {
    ref.read(wsClientProvider.notifier).send(WsCmd.stopBgm);
  }

  void _emergencyStop() {
    HapticFeedback.heavyImpact();
    ref.read(wsClientProvider.notifier).send(WsCmd.stopClip);
    ref.read(wsClientProvider.notifier).send(WsCmd.stopBgm);
  }
}
