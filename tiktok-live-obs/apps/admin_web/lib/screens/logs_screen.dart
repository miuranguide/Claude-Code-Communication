import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_data_providers.dart';
import '../widgets/admin_scaffold.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(logsStreamProvider);

    return AdminScaffold(
      title: '操作ログ',
      selectedIndex: 4,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161823),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white12),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 160, child: Text('日時',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(width: 120, child: Text('操作者',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(width: 120, child: Text('操作種別',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(child: Text('詳細',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
              Expanded(
                child: logsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 48,
                                color: Colors.white12),
                            SizedBox(height: 12),
                            Text('操作ログはまだありません',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _logRow(log);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _logRow(Map<String, dynamic> log) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              _formatDate(log['createdAt'] as String?),
              style:
                  const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              _shortenUid(log['actorUid'] as String? ?? ''),
              style:
                  const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          SizedBox(
            width: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _actionColor(log['action'] as String? ?? '')
                    .withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _actionLabel(log['action'] as String? ?? ''),
                style: TextStyle(
                  fontSize: 11,
                  color:
                      _actionColor(log['action'] as String? ?? ''),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              log['detail'] as String? ?? '',
              style:
                  const TextStyle(fontSize: 12, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _shortenUid(String uid) {
    if (uid.length > 8) return '${uid.substring(0, 8)}...';
    return uid;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'login':
        return 'ログイン';
      case 'logout':
        return 'ログアウト';
      case 'admin_login':
        return '管理ログイン';
      case 'admin_logout':
        return '管理ログアウト';
      case 'user_create':
        return 'ユーザー作成';
      case 'user_deactivate':
        return 'ユーザー無効化';
      case 'user_activate':
        return 'ユーザー有効化';
      case 'message_send':
        return 'メッセージ配信';
      case 'device_register':
        return '端末登録';
      case 'device_remove':
        return '端末解除';
      default:
        return action;
    }
  }

  Color _actionColor(String action) {
    if (action.contains('login')) return Colors.green;
    if (action.contains('logout')) return Colors.orange;
    if (action.contains('user')) return Colors.blue;
    if (action.contains('message')) return const Color(0xFFFE2C55);
    if (action.contains('device')) return const Color(0xFF25F4EE);
    return Colors.white54;
  }
}
