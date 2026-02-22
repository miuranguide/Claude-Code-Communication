import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'auth_provider.dart';

class DeviceState {
  final DeviceRegistration? registration;
  final bool isRegistering;
  final String? error;

  const DeviceState({this.registration, this.isRegistering = false, this.error});

  DeviceState copyWith({
    DeviceRegistration? registration,
    bool? isRegistering,
    String? error,
    bool clearReg = false,
    bool clearError = false,
  }) =>
      DeviceState(
        registration: clearReg ? null : (registration ?? this.registration),
        isRegistering: isRegistering ?? this.isRegistering,
        error: clearError ? null : (error ?? this.error),
      );
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  DeviceNotifier(this._ref) : super(const DeviceState());

  final Ref _ref;

  /// Register this device as a Display (broadcaster)
  Future<bool> registerAsDisplay() async {
    final auth = _ref.read(authProvider);
    if (!auth.isLoggedIn) return false;
    final user = auth.user!;

    state = state.copyWith(isRegistering: true, clearError: true);

    try {
      // Check device limit
      final count = await FirestoreService.instance
          .getDeviceCount(user.uid, DeviceType.display);
      if (count >= AppConstants.maxDisplayDevices) {
        state = state.copyWith(
          isRegistering: false,
          error: 'ディスプレイ端末の上限（${AppConstants.maxDisplayDevices}台）に達しています',
        );
        return false;
      }

      final deviceId = _getDeviceId();
      final reg = DeviceRegistration(
        id: '',
        uid: user.uid,
        deviceType: DeviceType.display,
        deviceId: deviceId,
        deviceName: Platform.localHostname,
        registeredAt: DateTime.now(),
        isOnline: true,
      );

      final docId = await FirestoreService.instance.registerDevice(reg);
      state = state.copyWith(
        registration: DeviceRegistration(
          id: docId,
          uid: reg.uid,
          deviceType: reg.deviceType,
          deviceId: reg.deviceId,
          deviceName: reg.deviceName,
          registeredAt: reg.registeredAt,
          isOnline: true,
        ),
        isRegistering: false,
      );

      FirestoreService.instance.writeLog(
        action: 'device_register',
        actorUid: user.uid,
        detail: 'Display device registered: $deviceId',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isRegistering: false,
        error: '端末登録に失敗しました: $e',
      );
      return false;
    }
  }

  /// Update online status
  Future<void> setOnline(bool online) async {
    final reg = state.registration;
    if (reg == null) return;
    try {
      await FirestoreService.instance.updateDeviceStatus(reg.id, online);
    } catch (e) {
      debugPrint('Device status update error: $e');
    }
  }

  /// Unregister device
  Future<void> unregister() async {
    final reg = state.registration;
    if (reg == null) return;
    try {
      await FirestoreService.instance.removeDevice(reg.id);
      state = state.copyWith(clearReg: true);
    } catch (e) {
      debugPrint('Device unregister error: $e');
    }
  }

  String _getDeviceId() {
    // Simple device fingerprint
    return '${Platform.operatingSystem}_${Platform.localHostname}_${DateTime.now().millisecondsSinceEpoch}';
  }
}

final deviceProvider =
    StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier(ref);
});
