import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared/shared.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:just_audio/just_audio.dart';

const _allowedVideoExts = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};
const _allowedAudioExts = {'.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac'};
const _maxFileSizeBytes = 500 * 1024 * 1024; // 500 MB

/// Clips state
class ClipListNotifier extends StateNotifier<List<Clip>> {
  ClipListNotifier() : super([]) {
    _initCompleter = Completer<void>();
    _load();
  }

  late final Completer<void> _initCompleter;
  Box<dynamic>? _box;

  Future<void> get initialized => _initCompleter.future;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox('clips');
    return _box!;
  }

  Future<void> _load() async {
    try {
      final box = await _getBox();
      final raw = box.get('list', defaultValue: '[]') as String;
      final list =
          (jsonDecode(raw) as List).map((e) => Clip.fromJson(e as Map<String, dynamic>)).toList();
      state = list;
    } catch (e) {
      debugPrint('Clip load error: $e');
    } finally {
      _initCompleter.complete();
    }
  }

  Future<void> _save() async {
    final box = await _getBox();
    await box.put('list', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  // Indexed lookup for O(1) searches
  Map<String, Clip> get _clipMap =>
      {for (final c in state) c.id: c};

  /// Generate thumbnail for video file
  Future<String?> _generateThumbnail(String videoPath, String clipId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final clipDir = Directory(p.join(dir.path, 'clips'));
      if (!clipDir.existsSync()) clipDir.createSync(recursive: true);

      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: clipDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 256,
        quality: 75,
      );
      if (thumbPath != null) {
        // Rename to standard name
        final dest = p.join(clipDir.path, '${clipId}_thumb.jpg');
        final thumbFile = File(thumbPath);
        if (thumbFile.existsSync()) {
          await thumbFile.rename(dest);
          return dest;
        }
      }
    } catch (e) {
      debugPrint('Thumbnail generation error: $e');
    }
    return null;
  }

  /// Extract video duration in milliseconds
  Future<int> _extractVideoDuration(String filePath) async {
    try {
      final ctrl = VideoPlayerController.file(File(filePath));
      await ctrl.initialize();
      final durationMs = ctrl.value.duration.inMilliseconds;
      await ctrl.dispose();
      return durationMs;
    } catch (e) {
      debugPrint('Video duration extraction error: $e');
      return 0;
    }
  }

  Future<bool> addClip(String name, File sourceFile) async {
    await initialized;
    if (state.length >= AppConstants.maxClips) return false;

    // Validate file
    if (!sourceFile.existsSync()) {
      debugPrint('addClip: file does not exist: ${sourceFile.path}');
      return false;
    }
    final ext = p.extension(sourceFile.path).toLowerCase();
    if (!_allowedVideoExts.contains(ext)) {
      debugPrint('addClip: unsupported extension: $ext');
      return false;
    }
    final fileSize = sourceFile.lengthSync();
    if (fileSize > _maxFileSizeBytes) {
      debugPrint('addClip: file too large: $fileSize bytes');
      return false;
    }

    final dir = await getApplicationDocumentsDirectory();
    final clipDir = Directory(p.join(dir.path, 'clips'));
    if (!clipDir.existsSync()) clipDir.createSync(recursive: true);

    final id = generateId('clip');
    final dest = p.join(clipDir.path, '$id$ext');
    await sourceFile.copy(dest);

    // Extract duration
    final durationMs = await _extractVideoDuration(dest);

    // Generate thumbnail
    final thumbnailPath = await _generateThumbnail(dest, id);

    final clip = Clip(
      id: id,
      name: name,
      category: ClipCategory.other,
      filePath: dest,
      durationMs: durationMs,
      thumbnailPath: thumbnailPath,
    );
    state = [...state, clip];
    await _save();
    return true;
  }

  Future<void> removeClip(String id) async {
    final clip = state.where((c) => c.id == id).firstOrNull;
    if (clip == null) return;
    final file = File(clip.filePath);
    if (file.existsSync()) file.deleteSync();
    // Delete thumbnail file
    if (clip.thumbnailPath != null) {
      final thumbFile = File(clip.thumbnailPath!);
      if (thumbFile.existsSync()) thumbFile.deleteSync();
    }
    state = state.where((c) => c.id != id).toList();
    await _save();
  }

  Future<void> updateClip(Clip clip) async {
    state = state.map((c) => c.id == clip.id ? clip : c).toList();
    await _save();
  }

  Future<void> updateLayout(String clipId, LayoutData layout) async {
    state = state.map((c) {
      if (c.id == clipId) {
        return Clip(
          id: c.id,
          name: c.name,
          category: c.category,
          filePath: c.filePath,
          durationMs: c.durationMs,
          layout: layout,
          cooldownMs: c.cooldownMs,
          thumbnailPath: c.thumbnailPath,
        );
      }
      return c;
    }).toList();
    await _save();
  }

  Clip? findById(String id) => _clipMap[id];
}

final clipListProvider =
    StateNotifierProvider<ClipListNotifier, List<Clip>>((ref) {
  return ClipListNotifier();
});

/// Tracks state
class TrackListNotifier extends StateNotifier<List<Track>> {
  TrackListNotifier() : super([]) {
    _initCompleter = Completer<void>();
    _load();
  }

  late final Completer<void> _initCompleter;
  Box<dynamic>? _box;

  Future<void> get initialized => _initCompleter.future;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox('tracks');
    return _box!;
  }

  Future<void> _load() async {
    try {
      final box = await _getBox();
      final raw = box.get('list', defaultValue: '[]') as String;
      final list =
          (jsonDecode(raw) as List).map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
      state = list;
    } catch (e) {
      debugPrint('Track load error: $e');
    } finally {
      _initCompleter.complete();
    }
  }

  Future<void> _save() async {
    final box = await _getBox();
    await box.put('list', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  /// Extract audio duration in milliseconds using just_audio
  Future<int> _extractAudioDuration(String filePath) async {
    try {
      final player = AudioPlayer();
      final duration = await player.setFilePath(filePath);
      final durationMs = duration?.inMilliseconds ?? 0;
      await player.dispose();
      return durationMs;
    } catch (e) {
      debugPrint('Audio duration extraction error: $e');
      return 0;
    }
  }

  Future<bool> addTrack(String name, File sourceFile) async {
    await initialized;
    if (state.length >= AppConstants.maxTracks) return false;

    // Validate file
    if (!sourceFile.existsSync()) {
      debugPrint('addTrack: file does not exist: ${sourceFile.path}');
      return false;
    }
    final ext = p.extension(sourceFile.path).toLowerCase();
    if (!_allowedAudioExts.contains(ext)) {
      debugPrint('addTrack: unsupported extension: $ext');
      return false;
    }
    final fileSize = sourceFile.lengthSync();
    if (fileSize > _maxFileSizeBytes) {
      debugPrint('addTrack: file too large: $fileSize bytes');
      return false;
    }

    final dir = await getApplicationDocumentsDirectory();
    final trackDir = Directory(p.join(dir.path, 'tracks'));
    if (!trackDir.existsSync()) trackDir.createSync(recursive: true);

    final id = generateId('bgm');
    final dest = p.join(trackDir.path, '$id$ext');
    await sourceFile.copy(dest);

    // Extract duration
    final durationMs = await _extractAudioDuration(dest);

    state = [
      ...state,
      Track(id: id, name: name, filePath: dest, durationMs: durationMs),
    ];
    await _save();
    return true;
  }

  Future<void> removeTrack(String id) async {
    final track = state.where((t) => t.id == id).firstOrNull;
    if (track == null) return;
    final file = File(track.filePath);
    if (file.existsSync()) file.deleteSync();
    state = state.where((t) => t.id != id).toList();
    await _save();
  }

  Future<void> updateTrack(Track track) async {
    state = state.map((t) => t.id == track.id ? track : t).toList();
    await _save();
  }
}

final trackListProvider =
    StateNotifierProvider<TrackListNotifier, List<Track>>((ref) {
  return TrackListNotifier();
});
