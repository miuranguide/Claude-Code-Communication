import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:shared/shared.dart';
import '../providers/asset_provider.dart';

class LayoutEditorScreen extends ConsumerStatefulWidget {
  final String clipId;
  const LayoutEditorScreen({super.key, required this.clipId});

  @override
  ConsumerState<LayoutEditorScreen> createState() =>
      _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends ConsumerState<LayoutEditorScreen> {
  late LayoutData _layout;
  VideoPlayerController? _videoCtrl;
  bool _dirty = false;

  // Gesture state
  double _scaleStart = 1.0;

  @override
  void initState() {
    super.initState();
    final clip =
        ref.read(clipListProvider.notifier).findById(widget.clipId);
    _layout = clip?.layout.copyWith() ?? LayoutData();
    _initPreview(clip);
  }

  Future<void> _initPreview(Clip? clip) async {
    if (clip == null) return;
    final file = File(clip.filePath);
    if (!file.existsSync()) return;
    _videoCtrl = VideoPlayerController.file(file);
    await _videoCtrl!.initialize();
    _videoCtrl!.setLooping(true);
    _videoCtrl!.setVolume(0);
    _videoCtrl!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _save() {
    ref
        .read(clipListProvider.notifier)
        .updateLayout(widget.clipId, _layout);
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('レイアウトを保存しました'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('リセット確認'),
        content: const Text('レイアウトをデフォルトに戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _layout = LayoutData();
                _dirty = true;
              });
            },
            child: const Text('リセット',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('レイアウト編集', style: TextStyle(fontSize: 16)),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: const Text('保存',
                  style: TextStyle(
                      color: Color(0xFFFE2C55),
                      fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'リセット',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas area (9:16 aspect ratio)
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: AppConstants.canvasAspect,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasW = constraints.maxWidth;
                      final canvasH = constraints.maxHeight;
                      return Stack(
                        children: [
                          // Background (simulated camera)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF1a1a2e),
                              child: const Center(
                                child: Text('カメラプレビュー',
                                    style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 14)),
                              ),
                            ),
                          ),

                          // Safe area guides
                          Positioned(
                            top: canvasH * AppConstants.safeTop,
                            left: canvasW * AppConstants.safeLeft,
                            right: canvasW * AppConstants.safeRight,
                            bottom: canvasH * AppConstants.safeBottom,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color:
                                        Colors.yellow.withAlpha(51),
                                    width: 1),
                              ),
                            ),
                          ),

                          // Center guides
                          Positioned(
                            top: canvasH / 2,
                            left: 0,
                            right: 0,
                            child: Container(
                                height: 0.5,
                                color:
                                    Colors.white.withAlpha(25)),
                          ),
                          Positioned(
                            left: canvasW / 2,
                            top: 0,
                            bottom: 0,
                            child: Container(
                                width: 0.5,
                                color:
                                    Colors.white.withAlpha(25)),
                          ),

                          // Draggable video overlay
                          _buildDraggableOverlay(canvasW, canvasH),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161823),
              border:
                  Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              children: [
                // Opacity timeline
                _buildOpacityTimeline(),
                const SizedBox(height: 8),
                _sliderRow(
                    'サイズ',
                    _layout.scaleNorm,
                    AppConstants.minScale,
                    AppConstants.maxScale, (v) {
                  setState(() {
                    _layout.scaleNorm = v;
                    _dirty = true;
                  });
                }, '${(_layout.scaleNorm * 100).round()}%'),
                _sliderRow('回転', _layout.rotationDeg, -180, 180,
                    (v) {
                  setState(() {
                    _layout.rotationDeg = v;
                    _dirty = true;
                  });
                }, '${_layout.rotationDeg.round()}°'),
                _sliderRow('音量', _layout.audioGain, 0, 2, (v) {
                  setState(() {
                    _layout.audioGain = v;
                    _dirty = true;
                  });
                }, '${(_layout.audioGain * 100).round()}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpacityTimeline() {
    final keyframes = _layout.effectiveOpacityKeyframes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Text('不透明度タイムライン',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
            const Spacer(),
            SizedBox(
              height: 28,
              width: 28,
              child: IconButton(
                icon: const Icon(Icons.add, size: 16),
                padding: EdgeInsets.zero,
                tooltip: 'キーフレーム追加',
                onPressed: _addKeyframe,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Timeline canvas
        SizedBox(
          height: 80,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  _onTimelineTap(details, constraints.maxWidth, 80);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 80),
                  painter: _OpacityTimelinePainter(keyframes: keyframes),
                  child: Stack(
                    clipBehavior: ui.Clip.none,
                    children: [
                      for (int i = 0; i < keyframes.length; i++)
                        _buildKeyframeHandle(
                            i, keyframes[i], constraints.maxWidth, 80),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Keyframe labels
        if (keyframes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              keyframes
                  .map((k) =>
                      '${(k.timeFraction * 100).round()}%→${(k.opacity * 100).round()}%')
                  .join('  '),
              style: const TextStyle(fontSize: 9, color: Colors.white30),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildKeyframeHandle(
      int index, OpacityKeyframe kf, double width, double height) {
    final x = kf.timeFraction * width - 8;
    final y = (1.0 - kf.opacity) * height - 8;
    final isEndpoint =
        kf.timeFraction <= 0.001 || kf.timeFraction >= 0.999;

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final keyframes =
                List<OpacityKeyframe>.from(_layout.opacityKeyframes.isEmpty
                    ? _layout.effectiveOpacityKeyframes
                    : _layout.opacityKeyframes);

            double newTime = keyframes[index].timeFraction;
            double newOpacity = keyframes[index].opacity;

            // Endpoints: only vertical drag (opacity)
            if (!isEndpoint) {
              newTime =
                  (newTime + d.delta.dx / width).clamp(0.01, 0.99);
            }
            newOpacity =
                (newOpacity - d.delta.dy / height).clamp(0.0, 1.0);

            keyframes[index] = OpacityKeyframe(
              timeFraction: newTime,
              opacity: newOpacity,
            );

            _layout.opacityKeyframes = keyframes;
            _layout.opacity = keyframes.first.opacity;
            _dirty = true;
          });
        },
        onLongPress: isEndpoint
            ? null
            : () {
                // Delete non-endpoint keyframes
                setState(() {
                  final keyframes = List<OpacityKeyframe>.from(
                      _layout.opacityKeyframes.isEmpty
                          ? _layout.effectiveOpacityKeyframes
                          : _layout.opacityKeyframes);
                  if (keyframes.length > 2) {
                    keyframes.removeAt(index);
                    _layout.opacityKeyframes = keyframes;
                    _dirty = true;
                  }
                });
              },
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEndpoint
                ? const Color(0xFFFE2C55)
                : const Color(0xFF25F4EE),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }

  void _addKeyframe() {
    setState(() {
      final keyframes = List<OpacityKeyframe>.from(
          _layout.opacityKeyframes.isEmpty
              ? _layout.effectiveOpacityKeyframes
              : _layout.opacityKeyframes);

      // Find the midpoint with the largest gap
      double maxGap = 0;
      int insertAfter = 0;
      final sorted = List<OpacityKeyframe>.from(keyframes)
        ..sort((a, b) => a.timeFraction.compareTo(b.timeFraction));
      for (int i = 0; i < sorted.length - 1; i++) {
        final gap = sorted[i + 1].timeFraction - sorted[i].timeFraction;
        if (gap > maxGap) {
          maxGap = gap;
          insertAfter = i;
        }
      }

      final midTime = (sorted[insertAfter].timeFraction +
              sorted[insertAfter + 1].timeFraction) /
          2;
      final midOpacity = (sorted[insertAfter].opacity +
              sorted[insertAfter + 1].opacity) /
          2;

      keyframes.add(OpacityKeyframe(
        timeFraction: midTime,
        opacity: midOpacity,
      ));

      _layout.opacityKeyframes = keyframes;
      _dirty = true;
    });
  }

  void _onTimelineTap(TapUpDetails details, double width, double height) {
    final timeFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final opacity =
        (1.0 - details.localPosition.dy / height).clamp(0.0, 1.0);

    // Check if tap is near an existing keyframe
    final keyframes = _layout.opacityKeyframes.isEmpty
        ? _layout.effectiveOpacityKeyframes
        : _layout.opacityKeyframes;
    for (final kf in keyframes) {
      final dx = (kf.timeFraction - timeFraction).abs() * width;
      final dy = (kf.opacity - opacity).abs() * height;
      if (dx < 20 && dy < 20) return; // Too close to existing point
    }

    setState(() {
      final newKeyframes = List<OpacityKeyframe>.from(keyframes);
      newKeyframes.add(OpacityKeyframe(
        timeFraction: timeFraction,
        opacity: opacity,
      ));
      _layout.opacityKeyframes = newKeyframes;
      _dirty = true;
    });
  }

  Widget _buildDraggableOverlay(double canvasW, double canvasH) {
    final videoW = canvasW * _layout.scaleNorm;
    final videoH =
        _videoCtrl != null && _videoCtrl!.value.isInitialized
            ? (_videoCtrl!.value.aspectRatio > 0
                ? videoW / _videoCtrl!.value.aspectRatio
                : videoW * 16 / 9)
            : videoW * 16 / 9;

    final left = _layout.xNorm * canvasW;
    final top = _layout.yNorm * canvasH;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (_) {},
        onPanUpdate: (d) {
          setState(() {
            _layout.xNorm =
                (_layout.xNorm + d.delta.dx / canvasW)
                    .clamp(0.0, 1.0 - _layout.scaleNorm);
            final maxY =
                (canvasH - videoH) / canvasH;
            _layout.yNorm =
                (_layout.yNorm + d.delta.dy / canvasH)
                    .clamp(0.0, maxY.clamp(0.0, 1.0));
            _dirty = true;
          });
        },
        onScaleStart: (_) {
          _scaleStart = _layout.scaleNorm;
        },
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            setState(() {
              _layout.scaleNorm = (_scaleStart * d.scale)
                  .clamp(
                      AppConstants.minScale, AppConstants.maxScale);
              _dirty = true;
            });
          }
        },
        child: Opacity(
          opacity: _layout.opacity,
          child: Container(
            width: videoW,
            height: videoH,
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFFFE2C55), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _videoCtrl != null &&
                      _videoCtrl!.value.isInitialized
                  ? VideoPlayer(_videoCtrl!)
                  : Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(Icons.videocam,
                            color: Colors.white24),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String display) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white54))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFE2C55),
                thumbColor: const Color(0xFFFE2C55),
                inactiveTrackColor: Colors.white12,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8),
              ),
              child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged),
            ),
          ),
          SizedBox(
              width: 44,
              child: Text(display,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white38))),
        ],
      ),
    );
  }
}

/// CustomPainter for the opacity timeline curve
class _OpacityTimelinePainter extends CustomPainter {
  final List<OpacityKeyframe> keyframes;

  _OpacityTimelinePainter({required this.keyframes});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()
      ..color = const Color(0xFF1a1a2e)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      bgPaint,
    );

    // Grid lines (horizontal)
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (keyframes.isEmpty) return;

    final sorted = List<OpacityKeyframe>.from(keyframes)
      ..sort((a, b) => a.timeFraction.compareTo(b.timeFraction));

    // Build path
    final path = Path();
    final fillPath = Path();

    final firstX = sorted.first.timeFraction * size.width;
    final firstY = (1.0 - sorted.first.opacity) * size.height;
    path.moveTo(firstX, firstY);
    fillPath.moveTo(firstX, size.height);
    fillPath.lineTo(firstX, firstY);

    for (int i = 1; i < sorted.length; i++) {
      final x = sorted[i].timeFraction * size.width;
      final y = (1.0 - sorted[i].opacity) * size.height;
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    final lastX = sorted.last.timeFraction * size.width;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();

    // Fill area
    final fillPaint = Paint()
      ..color = const Color(0xFFFE2C55).withAlpha(30)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke curve
    final linePaint = Paint()
      ..color = const Color(0xFFFE2C55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _OpacityTimelinePainter oldDelegate) {
    return oldDelegate.keyframes != keyframes;
  }
}
