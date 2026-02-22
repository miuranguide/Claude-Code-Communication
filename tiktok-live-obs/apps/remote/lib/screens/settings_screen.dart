import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import '../services/ws_client.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(wsClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF161823),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161823),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('接続情報',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: ws.connected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ws.connected ? '接続中' : '未接続',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (ws.broadcasterName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Broadcaster: ${ws.broadcasterName}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54),
                  ),
                ],
                if (ws.wsUrl != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ws.wsUrl!,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                InkWell(
                  onTap: () async {
                    await ref
                        .read(wsClientProvider.notifier)
                        .clearSavedConnection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('保存された接続情報をクリアしました')),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 20, color: Colors.white54),
                        SizedBox(width: 12),
                        Text('接続情報をクリア',
                            style: TextStyle(fontSize: 14)),
                        Spacer(),
                        Icon(Icons.chevron_right,
                            size: 20, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161823),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TikTok LIVE Remote v${AppConstants.appVersion}',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                const Text('StreamDeck風リモコンアプリ',
                    style:
                        TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
