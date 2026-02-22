import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import '../providers/auth_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/server_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _cooldownCtrl;

  @override
  void initState() {
    super.initState();
    final cd = ref.read(playbackProvider.notifier).cooldownMs;
    _cooldownCtrl = TextEditingController(text: cd.toString());
  }

  @override
  void dispose() {
    _cooldownCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = ref.watch(playbackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF161823),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cooldown
          _sectionTitle('連打防止'),
          _card(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('クールダウン (ms)',
                          style: TextStyle(fontSize: 14)),
                      Text('クリップ再生後の待機時間',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _cooldownCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) {
                      final ms = int.tryParse(v);
                      if (ms != null && ms >= 0) {
                        ref
                            .read(playbackProvider.notifier)
                            .setCooldown(ms);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('キュー動作'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('再生中にコマンドを受けた場合',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                _queueModeRadio(
                  'IGNORE (無視)',
                  '再生中のコマンドを無視する',
                  QueueMode.ignore,
                  pb.queueMode,
                ),
                _queueModeRadio(
                  'QUEUE (キュー)',
                  '再生待ちリストに追加して順番に再生',
                  QueueMode.queue,
                  pb.queueMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('音量プリセット'),
          _card(
            child: Column(
              children: [
                ...pb.presets.map((preset) => Column(
                      children: [
                        _presetRow(
                          preset.name,
                          'クリップ: ${(preset.clipGain * 100).round()}% / BGM: ${(preset.bgmGain * 100).round()}%',
                          isActive:
                              pb.activePresetName == preset.name,
                          onTap: () => ref
                              .read(playbackProvider.notifier)
                              .applyPreset(preset.name,
                                  preset.clipGain, preset.bgmGain),
                          onLongPress: () =>
                              _showPresetEditor(preset),
                        ),
                        const Divider(
                            height: 1, color: Colors.white12),
                      ],
                    )),
                // Add preset button
                InkWell(
                  onTap: _addPreset,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add,
                            size: 18, color: Colors.white38),
                        SizedBox(width: 6),
                        Text('プリセットを追加',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white38)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('アカウント'),
          _card(
            child: Column(
              children: [
                InkWell(
                  onTap: () => _showChangePasswordDialog(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 20, color: Colors.white54),
                        SizedBox(width: 12),
                        Text('パスワード変更', style: TextStyle(fontSize: 14)),
                        Spacer(),
                        Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                InkWell(
                  onTap: () => _confirmLogout(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text('ログアウト',
                            style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('サーバー'),
          _buildServerInfo(),

          const SizedBox(height: 24),
          _sectionTitle('情報'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'TikTok LIVE OBS v${AppConstants.appVersion}',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Flutter製 2台構成配信演出システム',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _queueModeRadio(
      String title, String subtitle, QueueMode mode, QueueMode current) {
    return InkWell(
      onTap: () =>
          ref.read(playbackProvider.notifier).setQueueMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              current == mode
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: current == mode
                  ? const Color(0xFFFE2C55)
                  : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: current == mode
                              ? const Color(0xFFFE2C55)
                              : Colors.white54)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo() {
    final ws = ref.watch(wsServerProvider);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: ws.isRunning ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                ws.isRunning ? 'サーバー起動中' : 'サーバー停止',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (ws.isRunning) ...[
            const SizedBox(height: 8),
            Text('IP: ${ws.localIp}:${ws.port}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white54)),
            Text('接続中: ${ws.connectedClients} 台',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white54)),
          ],
          if (ws.error != null) ...[
            const SizedBox(height: 8),
            Text(ws.error!,
                style: const TextStyle(
                    fontSize: 12, color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }

  void _addPreset() {
    final nameCtrl = TextEditingController();
    final clipCtrl = TextEditingController(text: '100');
    final bgmCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('プリセット追加',
            style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'プリセット名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: clipCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'クリップ音量 (%)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bgmCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'BGM音量 (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              nameCtrl.dispose();
              clipCtrl.dispose();
              bgmCtrl.dispose();
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final clip =
                  (int.tryParse(clipCtrl.text) ?? 100) / 100.0;
              final bgm =
                  (int.tryParse(bgmCtrl.text) ?? 30) / 100.0;
              if (name.isNotEmpty) {
                ref.read(playbackProvider.notifier).addPreset(
                      MixPreset(
                        id: generateId('preset'),
                        name: name,
                        clipGain: clip.clamp(0.0, 2.0),
                        bgmGain: bgm.clamp(0.0, 2.0),
                      ),
                    );
              }
              Navigator.pop(ctx);
              nameCtrl.dispose();
              clipCtrl.dispose();
              bgmCtrl.dispose();
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _showPresetEditor(MixPreset preset) {
    final nameCtrl = TextEditingController(text: preset.name);
    final clipCtrl = TextEditingController(
        text: (preset.clipGain * 100).round().toString());
    final bgmCtrl = TextEditingController(
        text: (preset.bgmGain * 100).round().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('プリセット編集',
            style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'プリセット名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: clipCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'クリップ音量 (%)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bgmCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'BGM音量 (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(playbackProvider.notifier)
                  .removePreset(preset.id);
              Navigator.pop(ctx);
              nameCtrl.dispose();
              clipCtrl.dispose();
              bgmCtrl.dispose();
            },
            child: const Text('削除',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              nameCtrl.dispose();
              clipCtrl.dispose();
              bgmCtrl.dispose();
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final clip =
                  (int.tryParse(clipCtrl.text) ?? 100) / 100.0;
              final bgm =
                  (int.tryParse(bgmCtrl.text) ?? 30) / 100.0;
              if (name.isNotEmpty) {
                ref.read(playbackProvider.notifier).updatePreset(
                      MixPreset(
                        id: preset.id,
                        name: name,
                        clipGain: clip.clamp(0.0, 2.0),
                        bgmGain: bgm.clamp(0.0, 2.0),
                      ),
                    );
              }
              Navigator.pop(ctx);
              nameCtrl.dispose();
              clipCtrl.dispose();
              bgmCtrl.dispose();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2333),
          title: const Text('パスワード変更', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '現在のパスワード',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新しいパスワード',
                  prefixIcon: Icon(Icons.lock, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新しいパスワード（確認）',
                  prefixIcon: Icon(Icons.lock, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                currentCtrl.dispose();
                newCtrl.dispose();
                confirmCtrl.dispose();
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: isChanging
                  ? null
                  : () async {
                      final current = currentCtrl.text;
                      final newPass = newCtrl.text;
                      final confirm = confirmCtrl.text;

                      if (current.isEmpty || newPass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('すべてのフィールドを入力してください')),
                        );
                        return;
                      }
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('パスワードは6文字以上にしてください')),
                        );
                        return;
                      }
                      if (newPass != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('新しいパスワードが一致しません')),
                        );
                        return;
                      }

                      setDialogState(() => isChanging = true);
                      final error = await ref
                          .read(authProvider.notifier)
                          .changePassword(current, newPass);

                      if (error == null) {
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          currentCtrl.dispose();
                          newCtrl.dispose();
                          confirmCtrl.dispose();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('パスワードを変更しました')),
                          );
                        }
                      } else {
                        setDialogState(() => isChanging = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                foregroundColor: Colors.white,
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('変更'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white54)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161823),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: child,
    );
  }

  Widget _presetRow(String name, String desc,
      {required bool isActive,
      required VoidCallback onTap,
      VoidCallback? onLongPress}) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: isActive
                  ? const Color(0xFFFE2C55)
                  : Colors.white38,
            ),
            const SizedBox(width: 10),
            Text(name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : Colors.white54)),
            const Spacer(),
            Text(desc,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}
