import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/message_provider.dart';

/// Top message bar widget — shows latest message from admin
/// Used in both broadcaster and remote apps
class MessageBar extends ConsumerWidget {
  final VoidCallback? onTap;

  const MessageBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgState = ref.watch(messageProvider);
    final msg = msgState.latestMessage;

    if (msg == null) return const SizedBox.shrink();

    final isUrgent = msg.isUrgent;
    final isRead = msgState.readIds.contains(msg.id);

    return GestureDetector(
      onTap: () {
        ref.read(messageProvider.notifier).markRead(msg.id);
        onTap?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUrgent
              ? const Color(0xFFFE2C55).withAlpha(230)
              : const Color(0xFF1C2333),
          border: Border(
            bottom: BorderSide(
              color: isUrgent
                  ? const Color(0xFFFE2C55)
                  : Colors.white12,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isUrgent ? Icons.warning_amber : Icons.mail_outline,
              size: 16,
              color: isUrgent ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isUrgent ? Colors.white : Colors.white70,
                  fontWeight:
                      isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFE2C55),
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (msgState.unreadCount > 1) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${msgState.unreadCount - 1}',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
