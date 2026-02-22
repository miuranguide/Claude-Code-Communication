import 'package:test/test.dart';
import 'package:shared/shared.dart';

void main() {
  group('Clip', () {
    test('toJson/fromJson roundtrip', () {
      final clip = Clip(
        id: 'clip_abc123',
        name: 'Test Clip',
        category: ClipCategory.win,
        filePath: '/path/to/video.mp4',
        durationMs: 5000,
        cooldownMs: 2000,
        layout: LayoutData(
          xNorm: 0.5,
          yNorm: 0.3,
          scaleNorm: 1.0,
          rotationDeg: 45.0,
          opacity: 0.8,
          zIndex: 5,
          fitMode: FitMode.cover,
          audioGain: 1.5,
        ),
      );

      final json = clip.toJson();
      final restored = Clip.fromJson(json);

      expect(restored.id, clip.id);
      expect(restored.name, clip.name);
      expect(restored.category, clip.category);
      expect(restored.filePath, clip.filePath);
      expect(restored.durationMs, clip.durationMs);
      expect(restored.cooldownMs, clip.cooldownMs);
      expect(restored.layout.xNorm, clip.layout.xNorm);
      expect(restored.layout.yNorm, clip.layout.yNorm);
      expect(restored.layout.scaleNorm, clip.layout.scaleNorm);
      expect(restored.layout.rotationDeg, clip.layout.rotationDeg);
      expect(restored.layout.opacity, clip.layout.opacity);
      expect(restored.layout.fitMode, FitMode.cover);
      expect(restored.layout.audioGain, 1.5);
    });

    test('fromJson with defaults', () {
      final json = {
        'id': 'clip_test',
        'name': 'Minimal',
        'filePath': '/test.mp4',
      };
      final clip = Clip.fromJson(json);
      expect(clip.category, ClipCategory.other);
      expect(clip.durationMs, 0);
      expect(clip.cooldownMs, 3000);
    });

    test('category parsing with invalid value', () {
      final json = {
        'id': 'clip_test',
        'name': 'Test',
        'filePath': '/test.mp4',
        'category': 'invalid_category',
      };
      final clip = Clip.fromJson(json);
      expect(clip.category, ClipCategory.other);
    });
  });

  group('LayoutData', () {
    test('toJson/fromJson roundtrip', () {
      final layout = LayoutData(
        xNorm: 0.25,
        yNorm: 0.75,
        scaleNorm: 1.5,
        rotationDeg: -30.0,
        opacity: 0.5,
        zIndex: 20,
        fitMode: FitMode.cover,
        audioGain: 0.8,
      );

      final json = layout.toJson();
      final restored = LayoutData.fromJson(json);

      expect(restored.xNorm, layout.xNorm);
      expect(restored.yNorm, layout.yNorm);
      expect(restored.scaleNorm, layout.scaleNorm);
      expect(restored.rotationDeg, layout.rotationDeg);
      expect(restored.opacity, layout.opacity);
      expect(restored.zIndex, layout.zIndex);
      expect(restored.fitMode, layout.fitMode);
      expect(restored.audioGain, layout.audioGain);
    });

    test('boundary validation clamps values', () {
      final layout = LayoutData(
        xNorm: -0.5,
        yNorm: 1.5,
        scaleNorm: 5.0,
        opacity: -1.0,
        audioGain: 10.0,
      );

      expect(layout.xNorm, 0.0);
      expect(layout.yNorm, 1.0);
      expect(layout.scaleNorm, AppConstants.maxScale);
      expect(layout.opacity, 0.0);
      expect(layout.audioGain, 2.0);
    });

    test('copyWith preserves values', () {
      final original = LayoutData(xNorm: 0.5, yNorm: 0.5);
      final modified = original.copyWith(xNorm: 0.8);

      expect(modified.xNorm, 0.8);
      expect(modified.yNorm, 0.5); // preserved
    });

    test('fitMode parsing', () {
      final json = {'fitMode': 'cover'};
      final layout = LayoutData.fromJson(json);
      expect(layout.fitMode, FitMode.cover);

      final json2 = {'fitMode': 'invalid'};
      final layout2 = LayoutData.fromJson(json2);
      expect(layout2.fitMode, FitMode.contain);
    });

    test('fromJson with empty map', () {
      final layout = LayoutData.fromJson({});
      expect(layout.xNorm, 0.15);
      expect(layout.yNorm, 0.15);
      expect(layout.scaleNorm, 0.7);
      expect(layout.fitMode, FitMode.contain);
    });
  });

  group('Track', () {
    test('toJson/fromJson roundtrip', () {
      final track = Track(
        id: 'bgm_abc',
        name: 'Battle BGM',
        filePath: '/path/to/bgm.mp3',
        defaultGain: 0.8,
        loop: false,
        durationMs: 180000,
      );

      final json = track.toJson();
      final restored = Track.fromJson(json);

      expect(restored.id, track.id);
      expect(restored.name, track.name);
      expect(restored.filePath, track.filePath);
      expect(restored.defaultGain, track.defaultGain);
      expect(restored.loop, track.loop);
      expect(restored.durationMs, track.durationMs);
    });

    test('fromJson with defaults', () {
      final json = {
        'id': 'bgm_test',
        'name': 'Test',
        'filePath': '/test.mp3',
      };
      final track = Track.fromJson(json);
      expect(track.defaultGain, 1.0);
      expect(track.loop, true);
      expect(track.durationMs, 0);
    });

    test('copyWith', () {
      final track = Track(
        id: 'bgm_test',
        name: 'Test',
        filePath: '/test.mp3',
      );
      final modified = track.copyWith(loop: false, name: 'New Name');
      expect(modified.loop, false);
      expect(modified.name, 'New Name');
      expect(modified.id, track.id);
    });
  });

  group('MixPreset', () {
    test('toJson/fromJson roundtrip', () {
      final preset = MixPreset(
        id: 'preset_1',
        name: 'バトル',
        clipGain: 1.0,
        bgmGain: 0.3,
      );

      final json = preset.toJson();
      final restored = MixPreset.fromJson(json);

      expect(restored.id, preset.id);
      expect(restored.name, preset.name);
      expect(restored.clipGain, preset.clipGain);
      expect(restored.bgmGain, preset.bgmGain);
    });

    test('fromJson with defaults', () {
      final json = {
        'id': 'preset_test',
        'name': 'Test',
      };
      final preset = MixPreset.fromJson(json);
      expect(preset.clipGain, 1.0);
      expect(preset.bgmGain, 0.3);
    });
  });

  group('OpacityKeyframe', () {
    test('toJson/fromJson roundtrip', () {
      final kf = OpacityKeyframe(timeFraction: 0.5, opacity: 0.75);
      final json = kf.toJson();
      final restored = OpacityKeyframe.fromJson(json);

      expect(restored.timeFraction, 0.5);
      expect(restored.opacity, 0.75);
    });

    test('copyWith', () {
      final kf = OpacityKeyframe(timeFraction: 0.3, opacity: 0.8);
      final modified = kf.copyWith(opacity: 0.2);

      expect(modified.timeFraction, 0.3);
      expect(modified.opacity, 0.2);
    });

    test('fromJson with defaults', () {
      final kf = OpacityKeyframe.fromJson({});
      expect(kf.timeFraction, 0.0);
      expect(kf.opacity, 1.0);
    });
  });

  group('LayoutData.interpolateOpacity', () {
    test('empty keyframes returns 1.0', () {
      expect(LayoutData.interpolateOpacity([], 0.5), 1.0);
    });

    test('single keyframe returns its value', () {
      final kfs = [OpacityKeyframe(timeFraction: 0.5, opacity: 0.3)];
      expect(LayoutData.interpolateOpacity(kfs, 0.0), 0.3);
      expect(LayoutData.interpolateOpacity(kfs, 1.0), 0.3);
    });

    test('two keyframes linear interpolation', () {
      final kfs = [
        OpacityKeyframe(timeFraction: 0.0, opacity: 0.0),
        OpacityKeyframe(timeFraction: 1.0, opacity: 1.0),
      ];
      expect(LayoutData.interpolateOpacity(kfs, 0.0), 0.0);
      expect(LayoutData.interpolateOpacity(kfs, 0.5), closeTo(0.5, 0.001));
      expect(LayoutData.interpolateOpacity(kfs, 1.0), 1.0);
    });

    test('three keyframes fade-in-out', () {
      final kfs = [
        OpacityKeyframe(timeFraction: 0.0, opacity: 0.0),
        OpacityKeyframe(timeFraction: 0.5, opacity: 1.0),
        OpacityKeyframe(timeFraction: 1.0, opacity: 0.0),
      ];
      expect(LayoutData.interpolateOpacity(kfs, 0.0), 0.0);
      expect(LayoutData.interpolateOpacity(kfs, 0.25), closeTo(0.5, 0.001));
      expect(LayoutData.interpolateOpacity(kfs, 0.5), 1.0);
      expect(LayoutData.interpolateOpacity(kfs, 0.75), closeTo(0.5, 0.001));
      expect(LayoutData.interpolateOpacity(kfs, 1.0), 0.0);
    });

    test('before first keyframe returns first value', () {
      final kfs = [
        OpacityKeyframe(timeFraction: 0.3, opacity: 0.5),
        OpacityKeyframe(timeFraction: 0.8, opacity: 1.0),
      ];
      expect(LayoutData.interpolateOpacity(kfs, 0.0), 0.5);
      expect(LayoutData.interpolateOpacity(kfs, 0.2), 0.5);
    });

    test('after last keyframe returns last value', () {
      final kfs = [
        OpacityKeyframe(timeFraction: 0.2, opacity: 0.3),
        OpacityKeyframe(timeFraction: 0.7, opacity: 0.8),
      ];
      expect(LayoutData.interpolateOpacity(kfs, 0.9), 0.8);
      expect(LayoutData.interpolateOpacity(kfs, 1.0), 0.8);
    });

    test('clamps time fraction', () {
      final kfs = [
        OpacityKeyframe(timeFraction: 0.0, opacity: 0.0),
        OpacityKeyframe(timeFraction: 1.0, opacity: 1.0),
      ];
      expect(LayoutData.interpolateOpacity(kfs, -0.5), 0.0);
      expect(LayoutData.interpolateOpacity(kfs, 1.5), 1.0);
    });

    test('unsorted keyframes are handled correctly', () {
      final kfs = [
        OpacityKeyframe(timeFraction: 1.0, opacity: 0.0),
        OpacityKeyframe(timeFraction: 0.0, opacity: 1.0),
        OpacityKeyframe(timeFraction: 0.5, opacity: 0.5),
      ];
      expect(LayoutData.interpolateOpacity(kfs, 0.0), 1.0);
      expect(LayoutData.interpolateOpacity(kfs, 0.5), 0.5);
      expect(LayoutData.interpolateOpacity(kfs, 1.0), 0.0);
    });
  });

  group('LayoutData.effectiveOpacityKeyframes', () {
    test('returns custom keyframes when set', () {
      final layout = LayoutData(
        opacityKeyframes: [
          OpacityKeyframe(timeFraction: 0.0, opacity: 0.0),
          OpacityKeyframe(timeFraction: 1.0, opacity: 1.0),
        ],
      );
      expect(layout.effectiveOpacityKeyframes.length, 2);
      expect(layout.effectiveOpacityKeyframes[0].opacity, 0.0);
    });

    test('generates fallback from opacity when empty', () {
      final layout = LayoutData(opacity: 0.6);
      final effective = layout.effectiveOpacityKeyframes;
      expect(effective.length, 2);
      expect(effective[0].timeFraction, 0.0);
      expect(effective[0].opacity, 0.6);
      expect(effective[1].timeFraction, 1.0);
      expect(effective[1].opacity, 0.6);
    });
  });

  group('LayoutData opacityKeyframes serialization', () {
    test('toJson/fromJson with keyframes', () {
      final layout = LayoutData(
        opacity: 0.5,
        opacityKeyframes: [
          OpacityKeyframe(timeFraction: 0.0, opacity: 0.0),
          OpacityKeyframe(timeFraction: 0.5, opacity: 1.0),
          OpacityKeyframe(timeFraction: 1.0, opacity: 0.0),
        ],
      );

      final json = layout.toJson();
      final restored = LayoutData.fromJson(json);

      expect(restored.opacityKeyframes.length, 3);
      expect(restored.opacityKeyframes[1].timeFraction, 0.5);
      expect(restored.opacityKeyframes[1].opacity, 1.0);
      expect(restored.opacity, 0.5); // legacy field preserved
    });

    test('fromJson without opacityKeyframes (backward compat)', () {
      final json = {
        'opacity': 0.8,
      };
      final layout = LayoutData.fromJson(json);
      expect(layout.opacityKeyframes, isEmpty);
      expect(layout.opacity, 0.8);
    });
  });

  group('Clip.thumbnailPath', () {
    test('toJson/fromJson with thumbnailPath', () {
      final clip = Clip(
        id: 'clip_1',
        name: 'Test',
        filePath: '/video.mp4',
        thumbnailPath: '/thumb.jpg',
      );
      final json = clip.toJson();
      final restored = Clip.fromJson(json);
      expect(restored.thumbnailPath, '/thumb.jpg');
    });

    test('fromJson without thumbnailPath (backward compat)', () {
      final json = {
        'id': 'clip_1',
        'name': 'Test',
        'filePath': '/video.mp4',
      };
      final clip = Clip.fromJson(json);
      expect(clip.thumbnailPath, isNull);
    });
  });

  group('AppConstants', () {
    test('appVersion is set', () {
      expect(AppConstants.appVersion, '1.3.0');
    });

    test('canvas aspect ratio', () {
      expect(AppConstants.canvasAspect, 9.0 / 16.0);
    });
  });

  group('QueueMode', () {
    test('enum values', () {
      expect(QueueMode.values.length, 2);
      expect(QueueMode.ignore.name, 'ignore');
      expect(QueueMode.queue.name, 'queue');
    });
  });

  group('FitMode', () {
    test('enum values', () {
      expect(FitMode.values.length, 2);
      expect(FitMode.contain.name, 'contain');
      expect(FitMode.cover.name, 'cover');
    });
  });
}
