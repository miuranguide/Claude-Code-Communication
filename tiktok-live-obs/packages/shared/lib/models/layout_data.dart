import '../utils/constants.dart';

/// A single keyframe for opacity animation over clip duration
class OpacityKeyframe {
  final double timeFraction; // 0.0〜1.0（タイムライン上の位置）
  final double opacity;      // 0.0〜1.0

  const OpacityKeyframe({
    required this.timeFraction,
    required this.opacity,
  });

  Map<String, dynamic> toJson() => {
        'timeFraction': timeFraction,
        'opacity': opacity,
      };

  factory OpacityKeyframe.fromJson(Map<String, dynamic> json) =>
      OpacityKeyframe(
        timeFraction: (json['timeFraction'] as num?)?.toDouble() ?? 0.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      );

  OpacityKeyframe copyWith({
    double? timeFraction,
    double? opacity,
  }) =>
      OpacityKeyframe(
        timeFraction: timeFraction ?? this.timeFraction,
        opacity: opacity ?? this.opacity,
      );
}

/// Normalized layout for 9:16 canvas (A方式)
/// All coordinates are 0..1 relative to the 9:16 virtual canvas
class LayoutData {
  double xNorm; // 0..1 left position
  double yNorm; // 0..1 top position
  double scaleNorm; // 0.1..2.0 scale factor
  double rotationDeg; // degrees
  double opacity; // 0..1 (legacy / fallback)
  int zIndex;
  FitMode fitMode;
  double audioGain; // 0..2
  List<OpacityKeyframe> opacityKeyframes;

  LayoutData({
    double xNorm = 0.15,
    double yNorm = 0.15,
    double scaleNorm = 0.7,
    this.rotationDeg = 0.0,
    double opacity = 1.0,
    this.zIndex = 10,
    this.fitMode = FitMode.contain,
    double audioGain = 1.0,
    List<OpacityKeyframe>? opacityKeyframes,
  })  : xNorm = xNorm.clamp(0.0, 1.0),
        yNorm = yNorm.clamp(0.0, 1.0),
        scaleNorm = scaleNorm.clamp(AppConstants.minScale, AppConstants.maxScale),
        opacity = opacity.clamp(0.0, 1.0),
        audioGain = audioGain.clamp(0.0, 2.0),
        opacityKeyframes = opacityKeyframes ?? [];

  /// Returns effective keyframes: if empty, generate 2-point keyframes
  /// from the legacy opacity field for backward compatibility
  List<OpacityKeyframe> get effectiveOpacityKeyframes {
    if (opacityKeyframes.isNotEmpty) return opacityKeyframes;
    return [
      OpacityKeyframe(timeFraction: 0.0, opacity: opacity),
      OpacityKeyframe(timeFraction: 1.0, opacity: opacity),
    ];
  }

  /// Linear interpolation of opacity at a given time fraction (0.0〜1.0)
  static double interpolateOpacity(
      List<OpacityKeyframe> keyframes, double timeFraction) {
    if (keyframes.isEmpty) return 1.0;
    if (keyframes.length == 1) return keyframes.first.opacity;

    // Clamp time
    final t = timeFraction.clamp(0.0, 1.0);

    // Sort by timeFraction
    final sorted = List<OpacityKeyframe>.from(keyframes)
      ..sort((a, b) => a.timeFraction.compareTo(b.timeFraction));

    // Before first keyframe
    if (t <= sorted.first.timeFraction) return sorted.first.opacity;
    // After last keyframe
    if (t >= sorted.last.timeFraction) return sorted.last.opacity;

    // Find surrounding keyframes and interpolate
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (t >= a.timeFraction && t <= b.timeFraction) {
        final range = b.timeFraction - a.timeFraction;
        if (range <= 0) return a.opacity;
        final ratio = (t - a.timeFraction) / range;
        return a.opacity + (b.opacity - a.opacity) * ratio;
      }
    }

    return sorted.last.opacity;
  }

  Map<String, dynamic> toJson() => {
        'xNorm': xNorm,
        'yNorm': yNorm,
        'scaleNorm': scaleNorm,
        'rotationDeg': rotationDeg,
        'opacity': opacity,
        'zIndex': zIndex,
        'fitMode': fitMode.name,
        'audioGain': audioGain,
        'opacityKeyframes':
            opacityKeyframes.map((k) => k.toJson()).toList(),
      };

  factory LayoutData.fromJson(Map<String, dynamic> json) => LayoutData(
        xNorm: (json['xNorm'] as num?)?.toDouble() ?? 0.15,
        yNorm: (json['yNorm'] as num?)?.toDouble() ?? 0.15,
        scaleNorm: (json['scaleNorm'] as num?)?.toDouble() ?? 0.7,
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as int?) ?? 10,
        fitMode: _parseFitMode(json['fitMode']),
        audioGain: (json['audioGain'] as num?)?.toDouble() ?? 1.0,
        opacityKeyframes: (json['opacityKeyframes'] as List?)
            ?.map((e) =>
                OpacityKeyframe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static FitMode _parseFitMode(dynamic value) {
    if (value is String) {
      return FitMode.values.where((e) => e.name == value).firstOrNull ??
          FitMode.contain;
    }
    return FitMode.contain;
  }

  LayoutData copyWith({
    double? xNorm,
    double? yNorm,
    double? scaleNorm,
    double? rotationDeg,
    double? opacity,
    int? zIndex,
    FitMode? fitMode,
    double? audioGain,
    List<OpacityKeyframe>? opacityKeyframes,
  }) =>
      LayoutData(
        xNorm: xNorm ?? this.xNorm,
        yNorm: yNorm ?? this.yNorm,
        scaleNorm: scaleNorm ?? this.scaleNorm,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        fitMode: fitMode ?? this.fitMode,
        audioGain: audioGain ?? this.audioGain,
        opacityKeyframes: opacityKeyframes ?? this.opacityKeyframes,
      );
}
