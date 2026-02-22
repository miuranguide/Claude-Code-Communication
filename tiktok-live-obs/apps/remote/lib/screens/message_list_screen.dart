import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/message_provider.dart';

class MessageListScreen extends ConsumerWidget {
  const MessageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgState = ref.watch(messageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージ', style: TextStyle(fontSize: 16)),
        actions: [
          if (msgState.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(messageProvider.notifier).markAllRead(),
              child: const Text('すべて既読',
                  style: TextStyle(fontSize: 12, color: Color(0xFFFE2C55))),
            ),
        ],
      ),
      body: msgState.messages.isEmpty
          ? const Center(
              child: Text('メッセージはありません',
                  style: TextStyle(color: Colors.white38)),
            )
          : ListView.builder(
              itemCount: msgState.messages.length,
              itemBuilder: (_, i) {
                final msg = msgState.messages[i];
                final isRead = msgState.readIds.contains(msg.id);

                return ListTile(
                  leading: Icon(
                    msg.isUrgent
                        ? Icons.warning_amber
                        : Icons.mail_outline,
                    color: msg.isUrgent
                        ? const Color(0xFFFE2C55)
                        : Colors.white54,
                  ),
                  title: Text(
                    msg.body,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(msg.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                  trailing: isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFE2C55),
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () {
                    ref.read(messageProvider.notifier).markRead(msg.id);
                  },
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
