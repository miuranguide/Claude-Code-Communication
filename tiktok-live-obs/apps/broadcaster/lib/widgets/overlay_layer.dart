import 'dart:io';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:shared/shared.dart';
import '../providers/playback_provider.dart';

class OverlayLayer extends ConsumerStatefulWidget {
  final Clip clip;
  const OverlayLayer({super.key, required this.clip});

  @override
  ConsumerState<OverlayLayer> createState() => _OverlayLayerState();
}

class _OverlayLayerState extends ConsumerState<OverlayLayer> {
  VideoPlayerController? _controller;
  bool _clipEndFired = false;
  double _currentOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _currentOpacity = widget.clip.layout.opacity;
    _initPlayer();
  }

  @override
  void didUpdateWidget(OverlayLayer old) {
    super.didUpdateWidget(old);
    if (old.clip.id != widget.clip.id) {
      _disposeController();
      _currentOpacity = widget.clip.layout.opacity;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    final file = File(widget.clip.filePath);
    if (!file.existsSync()) return;

    _clipEndFired = false;
    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
    // Apply clip's base gain multiplied by the active preset's clip gain
    final pb = ref.read(playbackProvider);
    _controller!.setVolume(widget.clip.layout.audioGain * pb.clipGain);
    _controller!.play();

    _controller!.addListener(_onVideoUpdate);

    if (mounted) setState(() {});
  }

  void _onVideoUpdate() {
    if (!mounted || _clipEndFired) return;
    final ctrl = _controller;
    if (ctrl == null) return;

    // Update opacity based on time position
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;
    if (duration > Duration.zero) {
      final timeFraction =
          position.inMilliseconds / duration.inMilliseconds;
      final keyframes = widget.clip.layout.effectiveOpacityKeyframes;
      final newOpacity =
          LayoutData.interpolateOpacity(keyframes, timeFraction);

      // Only setState if opacity changed significantly (performance)
      if ((newOpacity - _currentOpacity).abs() > 0.01) {
        setState(() {
          _currentOpacity = newOpacity;
        });
      }
    }

    // Check for clip end
    if (ctrl.value.position >= ctrl.value.duration &&
        ctrl.value.duration > Duration.zero) {
      _clipEndFired = true;
      ref.read(playbackProvider.notifier).clipEnded();
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final layout = widget.clip.layout;
    final screenSize = MediaQuery.of(context).size;

    // Map normalized layout to screen coordinates (9:16 canvas)
    final canvasW = screenSize.width;
    final canvasH = screenSize.height;

    final videoW = canvasW * layout.scaleNorm;
    final aspectRatio = _controller!.value.aspectRatio;
    final videoH = aspectRatio > 0 ? videoW / aspectRatio : videoW * 16 / 9;

    final left = layout.xNorm * canvasW;
    final top = layout.yNorm * canvasH;

    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: layout.rotationDeg * pi / 180,
        child: Opacity(
          opacity: _currentOpacity.clamp(0.0, 1.0),
          child: SizedBox(
            width: videoW,
            height: videoH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }
}
