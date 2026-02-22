import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared/shared.dart';
import '../providers/asset_provider.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen>
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

  static String _formatDuration(int ms) {
    if (ms <= 0) return '--:--';
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _layoutInfo(LayoutData layout) {
    // Position description
    String pos;
    if ((layout.xNorm - 0.15).abs() < 0.05 &&
        (layout.yNorm - 0.15).abs() < 0.05) {
      pos = '中央';
    } else if (layout.xNorm < 0.1) {
      pos = layout.yNorm < 0.1 ? '左上' : (layout.yNorm > 0.6 ? '左下' : '左');
    } else if (layout.xNorm > 0.5) {
      pos = layout.yNorm < 0.1 ? '右上' : (layout.yNorm > 0.6 ? '右下' : '右');
    } else {
      pos = layout.yNorm < 0.1 ? '上' : (layout.yNorm > 0.6 ? '下' : '中央');
    }

    final scale = '${(layout.scaleNorm * 100).round()}%';
    final rot = '回転${layout.rotationDeg.round()}°';
    return '$pos, $scale, $rot';
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipListProvider);
    final tracks = ref.watch(trackListProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('素材管理', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFFE2C55),
          tabs: [
            Tab(
                text:
                    '動画クリップ (${clips.length}/${AppConstants.maxClips})'),
            Tab(
                text:
                    'BGM (${tracks.length}/${AppConstants.maxTracks})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildClipList(clips),
          _buildTrackList(tracks),
        ],
      ),
    );
  }

  Widget _buildClipList(List<Clip> clips) {
    return Column(
      children: [
        // Add button
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: clips.length >= AppConstants.maxClips
                  ? null
                  : () => _addClip(),
              icon: const Icon(Icons.add),
              label: Text(clips.length >= AppConstants.maxClips
                  ? '上限に達しました (${AppConstants.maxClips}本)'
                  : '動画を追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[800],
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: clips.isEmpty
              ? const Center(
                  child: Text('動画クリップがありません',
                      style:
                          TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: clips.length,
                  itemBuilder: (_, i) => _clipTile(clips[i]),
                ),
        ),
      ],
    );
  }

  Widget _clipTile(Clip clip) {
    final hasThumbnail =
        clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasThumbnail
                  ? Image.file(
                      File(clip.thumbnailPath!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.videocam,
                          color: Colors.white38, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clip.name,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDuration(clip.durationMs)} | ${_layoutInfo(clip.layout)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white38),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: Colors.white54),
            tooltip: '名前を編集',
            onPressed: () => _renameClip(clip),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.grid_view, size: 20),
            tooltip: 'レイアウト編集',
            onPressed: () => context.push('/layout/${clip.id}'),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: Colors.redAccent),
            onPressed: () => _confirmDelete(clip),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(List<Track> tracks) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  tracks.length >= AppConstants.maxTracks
                      ? null
                      : () => _addTrack(),
              icon: const Icon(Icons.add),
              label: Text(
                  tracks.length >= AppConstants.maxTracks
                      ? '上限に達しました (${AppConstants.maxTracks}曲)'
                      : 'BGMを追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25F4EE),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[800],
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? const Center(
                  child: Text('BGMがありません',
                      style:
                          TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final track = tracks[i];
                    return ListTile(
                      leading: const Text('🎵',
                          style: TextStyle(fontSize: 28)),
                      title: Text(track.name,
                          style:
                              const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${_formatDuration(track.durationMs)} | ${track.loop ? 'ループ再生' : 'ワンショット'}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rename
                          IconButton(
                            icon: const Icon(Icons.edit,
                                size: 20, color: Colors.white54),
                            tooltip: '名前を編集',
                            onPressed: () => _renameTrack(track),
                          ),
                          // Loop toggle
                          IconButton(
                            icon: Icon(
                              track.loop
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              size: 20,
                              color: track.loop
                                  ? const Color(0xFF25F4EE)
                                  : Colors.white38,
                            ),
                            tooltip: track.loop
                                ? 'ループ: ON'
                                : 'ループ: OFF',
                            onPressed: () {
                              ref
                                  .read(trackListProvider
                                      .notifier)
                                  .updateTrack(track.copyWith(
                                      loop: !track.loop));
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.redAccent),
                            onPressed: () => ref
                                .read(
                                    trackListProvider.notifier)
                                .removeTrack(track.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addClip() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final name = result.files.first.name
        .replaceAll(RegExp(r'\.\w+$'), '');

    final ok = await ref
        .read(clipListProvider.notifier)
        .addClip(name, file);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('動画の追加に失敗しました（上限・形式・サイズを確認）')),
      );
    }
  }

  Future<void> _addTrack() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    // Auto-number: BGM 1, BGM 2, BGM 3...
    final currentCount = ref.read(trackListProvider).length;
    final name = 'BGM ${currentCount + 1}';

    final ok = await ref
        .read(trackListProvider.notifier)
        .addTrack(name, file);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('BGMの追加に失敗しました（上限・形式・サイズを確認）')),
      );
    }
  }

  void _renameClip(Clip clip) {
    final ctrl = TextEditingController(text: clip.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('クリップ名を編集', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名前',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ctrl.dispose();
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != clip.name) {
                final updated = Clip(
                  id: clip.id,
                  name: newName,
                  category: clip.category,
                  filePath: clip.filePath,
                  durationMs: clip.durationMs,
                  layout: clip.layout,
                  cooldownMs: clip.cooldownMs,
                  thumbnailPath: clip.thumbnailPath,
                );
                ref.read(clipListProvider.notifier).updateClip(updated);
              }
              Navigator.pop(dialogContext);
              ctrl.dispose();
            },
            child: const Text('保存',
                style: TextStyle(color: Color(0xFFFE2C55))),
          ),
        ],
      ),
    );
  }

  void _renameTrack(Track track) {
    final ctrl = TextEditingController(text: track.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('BGM名を編集', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名前',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ctrl.dispose();
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != track.name) {
                ref
                    .read(trackListProvider.notifier)
                    .updateTrack(track.copyWith(name: newName));
              }
              Navigator.pop(dialogContext);
              ctrl.dispose();
            },
            child: const Text('保存',
                style: TextStyle(color: Color(0xFF25F4EE))),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Clip clip) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${clip.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(clipListProvider.notifier)
                  .removeClip(clip.id);
              Navigator.pop(context);
            },
            child: const Text('削除',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
