import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/playback_provider.dart';

/// Invisible widget that handles BGM playback using just_audio.
/// Listens to PlaybackState and plays/stops BGM accordingly.
class BgmPlayer extends ConsumerStatefulWidget {
  const BgmPlayer({super.key});

  @override
  ConsumerState<BgmPlayer> createState() => _BgmPlayerState();
}

class _BgmPlayerState extends ConsumerState<BgmPlayer> {
  final AudioPlayer _player = AudioPlayer();
  String? _currentTrackId;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackState>(playbackProvider, (prev, next) {
      _handlePlaybackChange(prev, next);
    });

    // Invisible widget
    return const SizedBox.shrink();
  }

  Future<void> _handlePlaybackChange(
      PlaybackState? prev, PlaybackState next) async {
    // BGM gain changed
    if (prev != null && prev.bgmGain != next.bgmGain && _player.playing) {
      await _player.setVolume(next.bgmGain);
    }

    // BGM stopped
    if (prev?.bgmPlaying == true && !next.bgmPlaying) {
      await _player.stop();
      _currentTrackId = null;
      return;
    }

    // BGM started or changed
    if (next.bgmPlaying && next.activeBgm != null) {
      if (_currentTrackId != next.activeBgm!.id) {
        _currentTrackId = next.activeBgm!.id;
        try {
          await _player.setFilePath(next.activeBgm!.filePath);
          await _player.setVolume(next.bgmGain);
          await _player.setLoopMode(
              next.activeBgm!.loop ? LoopMode.one : LoopMode.off);
          await _player.play();
        } catch (e) {
          debugPrint('BGM play error: $e');
        }
      }
    }
  }
}
