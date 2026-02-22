import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/app_message.dart';
import '../models/device_registration.dart';

/// Centralized Firestore CRUD service for all collections.
class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _fs = FirebaseFirestore.instance;

  // ─── Collection references ───────────────────────────────
  CollectionReference<Map<String, dynamic>> get _users =>
      _fs.collection('users');
  CollectionReference<Map<String, dynamic>> get _messages =>
      _fs.collection('messages');
  CollectionReference<Map<String, dynamic>> get _devices =>
      _fs.collection('devices');
  CollectionReference<Map<String, dynamic>> get _logs =>
      _fs.collection('logs');

  // ═══════════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════════

  /// Get user document by uid
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromJson({...doc.data()!, 'uid': doc.id});
  }

  /// Get user by loginId (for auth lookup)
  Future<AppUser?> getUserByLoginId(String loginId) async {
    final snap = await _users
        .where('loginId', isEqualTo: loginId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return AppUser.fromJson({...doc.data(), 'uid': doc.id});
  }

  /// Create or update user
  Future<void> setUser(AppUser user) async {
    await _users.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }

  /// Get all users (admin)
  Stream<List<AppUser>> watchUsers() {
    return _users.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => AppUser.fromJson({...d.data(), 'uid': d.id}))
              .toList(),
        );
  }

  /// Deactivate user
  Future<void> deactivateUser(String uid) async {
    await _users.doc(uid).update({'isActive': false});
  }

  /// Activate user
  Future<void> activateUser(String uid) async {
    await _users.doc(uid).update({'isActive': true});
  }

  // ═══════════════════════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════════════════════

  /// Send a new message (admin)
  Future<String> sendMessage(AppMessage msg) async {
    final ref = await _messages.add(msg.toJson());
    return ref.id;
  }

  /// Watch messages for a specific user (by target matching)
  Stream<List<AppMessage>> watchMessagesForUser({
    required String uid,
    String? group,
    String? role,
  }) {
    // Listen to all messages, filter client-side for flexibility
    return _messages
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      final all = snap.docs.map((d) {
        return AppMessage.fromJson({...d.data(), 'id': d.id});
      }).toList();

      return all.where((m) {
        switch (m.target) {
          case MessageTarget.all:
            return true;
          case MessageTarget.individual:
            return m.targetValue == uid;
          case MessageTarget.group:
            return m.targetValue == group;
          case MessageTarget.role:
            return m.targetValue == role;
        }
      }).toList();
    });
  }

  /// Watch all messages (admin)
  Stream<List<AppMessage>> watchAllMessages() {
    return _messages
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppMessage.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════
  // DEVICES
  // ═══════════════════════════════════════════════════════════

  /// Register a device
  Future<String> registerDevice(DeviceRegistration device) async {
    final ref = await _devices.add(device.toJson());
    return ref.id;
  }

  /// Check device count for a user
  Future<int> getDeviceCount(String uid, DeviceType type) async {
    final snap = await _devices
        .where('uid', isEqualTo: uid)
        .where('deviceType', isEqualTo: type.name)
        .get();
    return snap.docs.length;
  }

  /// Get devices for a user
  Future<List<DeviceRegistration>> getDevicesForUser(String uid) async {
    final snap =
        await _devices.where('uid', isEqualTo: uid).get();
    return snap.docs
        .map((d) => DeviceRegistration.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  /// Update device online status
  Future<void> updateDeviceStatus(
      String deviceDocId, bool isOnline) async {
    await _devices.doc(deviceDocId).update({
      'isOnline': isOnline,
      'lastSeenAt': DateTime.now().toIso8601String(),
    });
  }

  /// Remove a device registration
  Future<void> removeDevice(String deviceDocId) async {
    await _devices.doc(deviceDocId).delete();
  }

  /// Watch all devices (admin)
  Stream<List<DeviceRegistration>> watchAllDevices() {
    return _devices
        .orderBy('registeredAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                DeviceRegistration.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════
  // LOGS
  // ═══════════════════════════════════════════════════════════

  /// Write an operation log
  Future<void> writeLog({
    required String action,
    required String actorUid,
    String? detail,
  }) async {
    await _logs.add({
      'action': action,
      'actorUid': actorUid,
      'detail': detail,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Watch logs (admin)
  Stream<List<Map<String, dynamic>>> watchLogs() {
    return _logs
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD STATS
  // ═══════════════════════════════════════════════════════════

  /// Get user counts for dashboard
  Future<Map<String, int>> getDashboardStats() async {
    final usersSnap = await _users.get();
    final activeSnap =
        await _users.where('isActive', isEqualTo: true).get();
    final controllersSnap = await _devices
        .where('deviceType', isEqualTo: 'controller')
        .where('isOnline', isEqualTo: true)
        .get();
    final displaysSnap = await _devices
        .where('deviceType', isEqualTo: 'display')
        .where('isOnline', isEqualTo: true)
        .get();
    return {
      'totalUsers': usersSnap.docs.length,
      'activeUsers': activeSnap.docs.length,
      'onlineControllers': controllersSnap.docs.length,
      'onlineDisplays': displaysSnap.docs.length,
    };
  }
}
