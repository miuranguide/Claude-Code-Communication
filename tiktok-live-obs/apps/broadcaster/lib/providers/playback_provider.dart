import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared/shared.dart';

/// Currently playing clip
class PlaybackState {
  final Clip? activeClip;
  final bool isPlaying;
  final Track? activeBgm;
  final bool bgmPlaying;
  final DateTime? lastClipTime; // for cooldown
  final double clipGain;
  final double bgmGain;
  final String activePresetName;
  final QueueMode queueMode;
  final List<Clip> queue;
  final List<MixPreset> presets;

  const PlaybackState({
    this.activeClip,
    this.isPlaying = false,
    this.activeBgm,
    this.bgmPlaying = false,
    this.lastClipTime,
    this.clipGain = 1.0,
    this.bgmGain = 0.3,
    this.activePresetName = 'バトル',
    this.queueMode = QueueMode.ignore,
    this.queue = const [],
    this.presets = const [],
  });

  int get queueLength => queue.length;

  PlaybackState copyWith({
    Clip? activeClip,
    bool? isPlaying,
    Track? activeBgm,
    bool? bgmPlaying,
    DateTime? lastClipTime,
    double? clipGain,
    double? bgmGain,
    String? activePresetName,
    QueueMode? queueMode,
    List<Clip>? queue,
    List<MixPreset>? presets,
    bool clearClip = false,
    bool clearBgm = false,
  }) =>
      PlaybackState(
        activeClip: clearClip ? null : (activeClip ?? this.activeClip),
        isPlaying: isPlaying ?? this.isPlaying,
        activeBgm: clearBgm ? null : (activeBgm ?? this.activeBgm),
        bgmPlaying: bgmPlaying ?? this.bgmPlaying,
        lastClipTime: lastClipTime ?? this.lastClipTime,
        clipGain: clipGain ?? this.clipGain,
        bgmGain: bgmGain ?? this.bgmGain,
        activePresetName: activePresetName ?? this.activePresetName,
        queueMode: queueMode ?? this.queueMode,
        queue: queue ?? this.queue,
        presets: presets ?? this.presets,
      );
}

class PlaybackNotifier extends StateNotifier<PlaybackState> {
  PlaybackNotifier() : super(const PlaybackState()) {
    _loadSettings();
  }

  int cooldownMs = AppConstants.defaultCooldownMs;

  static const _boxName = 'settings';
  Box<dynamic>? _box;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<void> _loadSettings() async {
    try {
      final box = await _getBox();
      cooldownMs = box.get('cooldownMs',
          defaultValue: AppConstants.defaultCooldownMs) as int;
      final presetName =
          box.get('activePreset', defaultValue: 'バトル') as String;
      final clipGain =
          (box.get('clipGain', defaultValue: 1.0) as num).toDouble();
      final bgmGain =
          (box.get('bgmGain', defaultValue: 0.3) as num).toDouble();
      final queueModeStr =
          box.get('queueMode', defaultValue: 'ignore') as String;
      final queueMode = QueueMode.values
              .where((e) => e.name == queueModeStr)
              .firstOrNull ??
          QueueMode.ignore;

      // Load custom presets
      final presetsRaw = box.get('presets', defaultValue: '[]') as String;
      final presets = (jsonDecode(presetsRaw) as List)
          .map((e) => MixPreset.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        clipGain: clipGain,
        bgmGain: bgmGain,
        activePresetName: presetName,
        queueMode: queueMode,
        presets: presets.isEmpty ? _defaultPresets : presets,
      );
    } catch (e) {
      debugPrint('PlaybackNotifier load error: $e');
      state = state.copyWith(presets: _defaultPresets);
    }
  }

  static final List<MixPreset> _defaultPresets = [
    MixPreset(
        id: 'preset_battle', name: 'バトル', clipGain: 1.0, bgmGain: 0.3),
    MixPreset(
        id: 'preset_talk', name: 'トーク', clipGain: 0.6, bgmGain: 0.15),
  ];

  Future<void> _saveSettings() async {
    final box = await _getBox();
    await box.put('cooldownMs', cooldownMs);
    await box.put('activePreset', state.activePresetName);
    await box.put('clipGain', state.clipGain);
    await box.put('bgmGain', state.bgmGain);
    await box.put('queueMode', state.queueMode.name);
    await box.put('presets',
        jsonEncode(state.presets.map((e) => e.toJson()).toList()));
  }

  Future<void> setCooldown(int ms) async {
    cooldownMs = ms;
    await _saveSettings();
  }

  Future<void> setQueueMode(QueueMode mode) async {
    state = state.copyWith(queueMode: mode);
    await _saveSettings();
  }

  bool get isCooldownActive {
    if (state.lastClipTime == null) return false;
    return DateTime.now().difference(state.lastClipTime!).inMilliseconds <
        cooldownMs;
  }

  void playClip(Clip clip) {
    if (isCooldownActive) return;

    if (state.isPlaying) {
      // Queue mode handling
      if (state.queueMode == QueueMode.queue) {
        state = state.copyWith(queue: [...state.queue, clip]);
        return;
      }
      // ignore mode - do nothing
      return;
    }

    state = state.copyWith(
      activeClip: clip,
      isPlaying: true,
      lastClipTime: DateTime.now(),
    );
  }

  void stopClip() {
    state = state.copyWith(
        isPlaying: false, clearClip: true, queue: const []);
  }

  void clipEnded() {
    // Check queue for next clip
    if (state.queue.isNotEmpty) {
      final next = state.queue.first;
      final remaining = state.queue.sublist(1);
      state = state.copyWith(
        activeClip: next,
        isPlaying: true,
        lastClipTime: DateTime.now(),
        queue: remaining,
      );
      return;
    }
    state = state.copyWith(isPlaying: false, clearClip: true);
  }

  void playBgm(Track track) {
    state = state.copyWith(activeBgm: track, bgmPlaying: true);
  }

  void stopBgm() {
    state = state.copyWith(bgmPlaying: false, clearBgm: true);
  }

  /// Apply mix preset
  void applyPreset(String name, double clipGain, double bgmGain) {
    state = state.copyWith(
      clipGain: clipGain,
      bgmGain: bgmGain,
      activePresetName: name,
    );
    _saveSettings();
  }

  /// Add custom preset
  void addPreset(MixPreset preset) {
    state = state.copyWith(presets: [...state.presets, preset]);
    _saveSettings();
  }

  /// Update existing preset
  void updatePreset(MixPreset preset) {
    state = state.copyWith(
      presets:
          state.presets.map((p) => p.id == preset.id ? preset : p).toList(),
    );
    _saveSettings();
  }

  /// Remove preset
  void removePreset(String presetId) {
    state = state.copyWith(
      presets: state.presets.where((p) => p.id != presetId).toList(),
    );
    _saveSettings();
  }

  /// Emergency stop all
  void stopAll() {
    state = PlaybackState(
      clipGain: state.clipGain,
      bgmGain: state.bgmGain,
      activePresetName: state.activePresetName,
      queueMode: state.queueMode,
      presets: state.presets,
    );
  }
}

final playbackProvider =
    StateNotifierProvider<PlaybackNotifier, PlaybackState>((ref) {
  return PlaybackNotifier();
});
