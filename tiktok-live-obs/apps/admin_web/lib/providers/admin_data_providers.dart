import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

/// Stream provider for all users
final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return FirestoreService.instance.watchUsers();
});

/// Stream provider for all messages
final messagesStreamProvider = StreamProvider<List<AppMessage>>((ref) {
  return FirestoreService.instance.watchAllMessages();
});

/// Stream provider for all devices
final devicesStreamProvider = StreamProvider<List<DeviceRegistration>>((ref) {
  return FirestoreService.instance.watchAllDevices();
});

/// Stream provider for operation logs
final logsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirestoreService.instance.watchLogs();
});

/// Future provider for dashboard stats
final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) {
  return FirestoreService.instance.getDashboardStats();
});
