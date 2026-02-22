import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AssignState {
  final String? winClipId;
  final String? loseClipId;
  final String? other1ClipId;
  final String? other2ClipId;
  final String winLabel;
  final String loseLabel;
  final String other1Label;
  final String other2Label;

  const AssignState({
    this.winClipId,
    this.loseClipId,
    this.other1ClipId,
    this.other2ClipId,
    this.winLabel = '',
    this.loseLabel = '',
    this.other1Label = '',
    this.other2Label = '',
  });

  AssignState copyWith({
    String? winClipId,
    String? loseClipId,
    String? other1ClipId,
    String? other2ClipId,
    String? winLabel,
    String? loseLabel,
    String? other1Label,
    String? other2Label,
    bool clearWin = false,
    bool clearLose = false,
    bool clearOther1 = false,
    bool clearOther2 = false,
  }) =>
      AssignState(
        winClipId: clearWin ? null : (winClipId ?? this.winClipId),
        loseClipId:
            clearLose ? null : (loseClipId ?? this.loseClipId),
        other1ClipId:
            clearOther1 ? null : (other1ClipId ?? this.other1ClipId),
        other2ClipId:
            clearOther2 ? null : (other2ClipId ?? this.other2ClipId),
        winLabel: winLabel ?? this.winLabel,
        loseLabel: loseLabel ?? this.loseLabel,
        other1Label: other1Label ?? this.other1Label,
        other2Label: other2Label ?? this.other2Label,
      );
}

class AssignNotifier extends StateNotifier<AssignState> {
  AssignNotifier() : super(const AssignState()) {
    _load();
  }

  static const _boxName = 'assigns';
  Box<dynamic>? _box;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<void> _load() async {
    try {
      final box = await _getBox();
      state = AssignState(
        winClipId: box.get('winClipId') as String?,
        loseClipId: box.get('loseClipId') as String?,
        other1ClipId: box.get('other1ClipId') as String?,
        other2ClipId: box.get('other2ClipId') as String?,
        winLabel: box.get('winLabel', defaultValue: '') as String,
        loseLabel: box.get('loseLabel', defaultValue: '') as String,
        other1Label: box.get('other1Label', defaultValue: '') as String,
        other2Label: box.get('other2Label', defaultValue: '') as String,
      );
    } catch (e) {
      debugPrint('AssignNotifier load error: $e');
    }
  }

  Future<void> _save() async {
    final box = await _getBox();
    await box.put('winClipId', state.winClipId);
    await box.put('loseClipId', state.loseClipId);
    await box.put('other1ClipId', state.other1ClipId);
    await box.put('other2ClipId', state.other2ClipId);
    await box.put('winLabel', state.winLabel);
    await box.put('loseLabel', state.loseLabel);
    await box.put('other1Label', state.other1Label);
    await box.put('other2Label', state.other2Label);
  }

  void setWin(String? clipId) {
    state =
        state.copyWith(winClipId: clipId, clearWin: clipId == null);
    _save();
  }

  void setLose(String? clipId) {
    state = state.copyWith(
        loseClipId: clipId, clearLose: clipId == null);
    _save();
  }

  void setOther1(String? clipId) {
    state = state.copyWith(
        other1ClipId: clipId, clearOther1: clipId == null);
    _save();
  }

  void setOther2(String? clipId) {
    state = state.copyWith(
        other2ClipId: clipId, clearOther2: clipId == null);
    _save();
  }

  void setLabel(int slot, String label) {
    switch (slot) {
      case 0:
        state = state.copyWith(winLabel: label);
        break;
      case 1:
        state = state.copyWith(loseLabel: label);
        break;
      case 2:
        state = state.copyWith(other1Label: label);
        break;
      case 3:
        state = state.copyWith(other2Label: label);
        break;
    }
    _save();
  }
}

final assignProvider =
    StateNotifierProvider<AssignNotifier, AssignState>((ref) {
  return AssignNotifier();
});
