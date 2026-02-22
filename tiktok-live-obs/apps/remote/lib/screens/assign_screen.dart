import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/ws_client.dart';
import '../providers/assign_provider.dart';

class AssignScreen extends ConsumerWidget {
  const AssignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(wsClientProvider);
    final assigns = ref.watch(assignProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('ボタン割当', style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF161823),
      ),
      body: ws.clips.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Broadcasterに接続してクリップを登録してください',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '各ボタンに名前とクリップを割り当てます',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                _AssignTile(
                  slot: 0,
                  label: assigns.winLabel,
                  color: const Color(0xFF3fb950),
                  selectedClipId: assigns.winClipId,
                  clips: ws.clips,
                  onClipChanged: (id) =>
                      ref.read(assignProvider.notifier).setWin(id),
                  onLabelChanged: (label) =>
                      ref.read(assignProvider.notifier).setLabel(0, label),
                ),
                const SizedBox(height: 12),
                _AssignTile(
                  slot: 1,
                  label: assigns.loseLabel,
                  color: const Color(0xFFF85149),
                  selectedClipId: assigns.loseClipId,
                  clips: ws.clips,
                  onClipChanged: (id) =>
                      ref.read(assignProvider.notifier).setLose(id),
                  onLabelChanged: (label) =>
                      ref.read(assignProvider.notifier).setLabel(1, label),
                ),
                const SizedBox(height: 12),
                _AssignTile(
                  slot: 2,
                  label: assigns.other1Label,
                  color: const Color(0xFF58A6FF),
                  selectedClipId: assigns.other1ClipId,
                  clips: ws.clips,
                  onClipChanged: (id) =>
                      ref.read(assignProvider.notifier).setOther1(id),
                  onLabelChanged: (label) =>
                      ref.read(assignProvider.notifier).setLabel(2, label),
                ),
                const SizedBox(height: 12),
                _AssignTile(
                  slot: 3,
                  label: assigns.other2Label,
                  color: const Color(0xFFBC8CFF),
                  selectedClipId: assigns.other2ClipId,
                  clips: ws.clips,
                  onClipChanged: (id) =>
                      ref.read(assignProvider.notifier).setOther2(id),
                  onLabelChanged: (label) =>
                      ref.read(assignProvider.notifier).setLabel(3, label),
                ),
              ],
            ),
    );
  }
}

class _AssignTile extends StatelessWidget {
  final int slot;
  final String label;
  final Color color;
  final String? selectedClipId;
  final List<Map<String, dynamic>> clips;
  final ValueChanged<String?> onClipChanged;
  final ValueChanged<String> onLabelChanged;

  const _AssignTile({
    required this.slot,
    required this.label,
    required this.color,
    required this.selectedClipId,
    required this.clips,
    required this.onClipChanged,
    required this.onLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedName = selectedClipId != null
        ? clips
            .where((c) => c['id'] == selectedClipId)
            .map((c) => c['name'] as String?)
            .firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row (editable)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editLabel(context),
                  child: Row(
                    children: [
                      Text(
                        label.isEmpty ? 'タップして名前を設定' : label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: label.isEmpty ? FontWeight.w400 : FontWeight.w700,
                          color: label.isEmpty ? Colors.white24 : color,
                          letterSpacing: label.isEmpty ? 0 : 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined,
                          size: 14, color: color.withAlpha(127)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Clip assignment row
          Row(
            children: [
              const Icon(Icons.movie_outlined,
                  size: 18, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedName ?? '未設定',
                  style: TextStyle(
                    fontSize: 13,
                    color: selectedName != null
                        ? Colors.white70
                        : Colors.white24,
                  ),
                ),
              ),
              PopupMenuButton<String?>(
                icon: Icon(Icons.swap_horiz,
                    color: color.withAlpha(178), size: 20),
                color: const Color(0xFF1C2333),
                onSelected: onClipChanged,
                tooltip: 'クリップを選択',
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: null,
                    child: Text('なし（解除）',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  ),
                  ...clips.map((clip) => PopupMenuItem(
                        value: clip['id'] as String,
                        child: Row(
                          children: [
                            if (clip['id'] == selectedClipId)
                              const Icon(Icons.check,
                                  size: 16, color: Colors.green)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                clip['name'] as String? ?? 'Clip',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              _categoryLabel(
                                  clip['category'] as String?),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white38),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editLabel(BuildContext context) {
    final ctrl = TextEditingController(text: label);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('ボタン名を編集',
            style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(
            labelText: 'ボタン名',
            hintText: '例: 勝ち、負け、ダンス',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final newLabel = ctrl.text.trim();
              if (newLabel.isNotEmpty) {
                onLabelChanged(newLabel);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('保存',
                style: TextStyle(color: Color(0xFFFE2C55))),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'win':
        return '🏆';
      case 'lose':
        return '💀';
      default:
        return '🎬';
    }
  }
}
