import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_data_providers.dart';
import '../widgets/admin_scaffold.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider);

    return AdminScaffold(
      title: 'メッセージ配信',
      selectedIndex: 2,
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showComposeDialog(context),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('新規配信'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFE2C55),
            foregroundColor: Colors.white,
          ),
        ),
      ],
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
                    SizedBox(width: 80, child: Text('優先度',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(child: Text('本文',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(width: 100, child: Text('配信先',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(width: 120, child: Text('日時',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('メッセージはまだありません',
                            style: TextStyle(color: Colors.white38)),
                      );
                    }
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _messageRow(msg);
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

  Widget _messageRow(AppMessage msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: msg.isUrgent
                    ? const Color(0xFFFE2C55).withAlpha(50)
                    : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                msg.isUrgent ? '緊急' : '通常',
                style: TextStyle(
                  fontSize: 11,
                  color: msg.isUrgent
                      ? const Color(0xFFFE2C55)
                      : Colors.white54,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(msg.body,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _targetLabel(msg.target, msg.targetValue),
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              _formatDate(msg.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  String _targetLabel(MessageTarget target, String? value) {
    switch (target) {
      case MessageTarget.all:
        return '全体';
      case MessageTarget.individual:
        return '個別: ${value ?? ''}';
      case MessageTarget.group:
        return 'G: ${value ?? ''}';
      case MessageTarget.role:
        return 'R: ${value ?? ''}';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showComposeDialog(BuildContext context) {
    final bodyCtrl = TextEditingController();
    var target = MessageTarget.all;
    var priority = MessagePriority.normal;
    final targetValueCtrl = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('メッセージ配信'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'メッセージ本文 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('配信先',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in MessageTarget.values)
                      ChoiceChip(
                        label: Text(_targetChipLabel(t)),
                        selected: target == t,
                        onSelected: (_) =>
                            setDialogState(() => target = t),
                      ),
                  ],
                ),
                if (target != MessageTarget.all) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetValueCtrl,
                    decoration: InputDecoration(
                      labelText: target == MessageTarget.individual
                          ? 'ユーザーID'
                          : target == MessageTarget.group
                              ? 'グループ名'
                              : 'ロール名',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('優先度',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('通常'),
                      selected: priority == MessagePriority.normal,
                      onSelected: (_) => setDialogState(
                          () => priority = MessagePriority.normal),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('緊急'),
                      selected: priority == MessagePriority.urgent,
                      selectedColor: const Color(0xFFFE2C55),
                      onSelected: (_) => setDialogState(
                          () => priority = MessagePriority.urgent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final body = bodyCtrl.text.trim();
                      if (body.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('本文を入力してください')),
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);

                      try {
                        final admin = ref.read(adminAuthProvider).user;
                        final msg = AppMessage(
                          id: '',
                          body: body,
                          priority: priority,
                          target: target,
                          targetValue: target != MessageTarget.all
                              ? targetValueCtrl.text.trim()
                              : null,
                          createdAt: DateTime.now(),
                          createdBy: admin?.uid ?? 'unknown',
                        );

                        await FirestoreService.instance.sendMessage(msg);

                        if (admin != null) {
                          FirestoreService.instance.writeLog(
                            action: 'message_send',
                            actorUid: admin.uid,
                            detail:
                                'Sent ${priority.name} message to ${target.name}',
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('メッセージを配信しました')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: $e')),
                          );
                        }
                      }

                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                foregroundColor: Colors.white,
              ),
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('配信'),
            ),
          ],
        ),
      ),
    );
  }

  String _targetChipLabel(MessageTarget t) {
    switch (t) {
      case MessageTarget.all:
        return '全体';
      case MessageTarget.individual:
        return '個別';
      case MessageTarget.group:
        return 'グループ';
      case MessageTarget.role:
        return 'ロール別';
    }
  }
}
