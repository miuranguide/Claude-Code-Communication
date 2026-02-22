import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_data_providers.dart';
import '../widgets/admin_scaffold.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final logsAsync = ref.watch(logsStreamProvider);

    return AdminScaffold(
      title: 'ダッシュボード',
      selectedIndex: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(dashboardStatsProvider),
          tooltip: '更新',
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  _statCard('総ユーザー数', '${stats['totalUsers'] ?? 0}',
                      Icons.people, Colors.blue),
                  const SizedBox(width: 16),
                  _statCard('アクティブ', '${stats['activeUsers'] ?? 0}',
                      Icons.check_circle, Colors.green),
                  const SizedBox(width: 16),
                  _statCard(
                      'オンライン（Controller）',
                      '${stats['onlineControllers'] ?? 0}',
                      Icons.phone_android,
                      const Color(0xFFFE2C55)),
                  const SizedBox(width: 16),
                  _statCard(
                      'オンライン（Display）',
                      '${stats['onlineDisplays'] ?? 0}',
                      Icons.tv,
                      const Color(0xFF25F4EE)),
                ],
              ),
              loading: () => Row(
                children: [
                  _statCard('総ユーザー数', '...', Icons.people, Colors.blue),
                  const SizedBox(width: 16),
                  _statCard(
                      'アクティブ', '...', Icons.check_circle, Colors.green),
                  const SizedBox(width: 16),
                  _statCard('オンライン（Controller）', '...',
                      Icons.phone_android, const Color(0xFFFE2C55)),
                  const SizedBox(width: 16),
                  _statCard('オンライン（Display）', '...', Icons.tv,
                      const Color(0xFF25F4EE)),
                ],
              ),
              error: (e, _) => Row(
                children: [
                  _statCard('エラー', '-', Icons.error, Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '最近の操作',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161823),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: logsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Center(
                        child: Text('操作ログはまだありません',
                            style: TextStyle(color: Colors.white38)),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.length > 10 ? 10 : logs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _logIcon(log['action'] as String? ?? ''),
                            size: 20,
                            color: Colors.white38,
                          ),
                          title: Text(
                            log['action'] as String? ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            log['detail'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38),
                          ),
                          trailing: Text(
                            _formatDate(log['createdAt'] as String?),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('エラー: $e',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _logIcon(String action) {
    if (action.contains('login')) return Icons.login;
    if (action.contains('logout')) return Icons.logout;
    if (action.contains('device')) return Icons.devices;
    if (action.contains('user')) return Icons.person;
    if (action.contains('message')) return Icons.message;
    return Icons.history;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161823),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
