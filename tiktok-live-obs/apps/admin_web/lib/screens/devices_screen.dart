import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_data_providers.dart';
import '../widgets/admin_scaffold.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  String _filter = 'all'; // all, controller, display, online

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    return AdminScaffold(
      title: '端末管理',
      selectedIndex: 3,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilterChip(
                  label: const Text('全て'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Controller'),
                  selected: _filter == 'controller',
                  onSelected: (_) =>
                      setState(() => _filter = 'controller'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Display'),
                  selected: _filter == 'display',
                  onSelected: (_) =>
                      setState(() => _filter = 'display'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('オンラインのみ'),
                  selected: _filter == 'online',
                  onSelected: (_) =>
                      setState(() => _filter = 'online'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161823),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 80, child: Text('状態',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 100, child: Text('種別',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 150, child: Text('ユーザー',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(child: Text('端末名',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 120, child: Text('最終接続',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 80, child: Text('操作',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: devicesAsync.when(
                        data: (devices) {
                          // Build user lookup map
                          final userMap = <String, AppUser>{};
                          usersAsync.whenData((users) {
                            for (final u in users) {
                              userMap[u.uid] = u;
                            }
                          });

                          final filtered = devices.where((d) {
                            switch (_filter) {
                              case 'controller':
                                return d.deviceType ==
                                    DeviceType.controller;
                              case 'display':
                                return d.deviceType ==
                                    DeviceType.display;
                              case 'online':
                                return d.isOnline;
                              default:
                                return true;
                            }
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.devices, size: 48,
                                      color: Colors.white12),
                                  SizedBox(height: 12),
                                  Text('端末はまだ登録されていません',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13)),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final device = filtered[index];
                              final owner = userMap[device.uid];
                              return _deviceRow(device, owner);
                            },
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text('エラー: $e',
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceRow(DeviceRegistration device, AppUser? owner) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: device.isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  device.isOnline ? 'オンライン' : 'オフライン',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: device.deviceType == DeviceType.controller
                    ? const Color(0xFFFE2C55).withAlpha(30)
                    : const Color(0xFF25F4EE).withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                device.deviceType == DeviceType.controller
                    ? 'Controller'
                    : 'Display',
                style: TextStyle(
                  fontSize: 11,
                  color: device.deviceType == DeviceType.controller
                      ? const Color(0xFFFE2C55)
                      : const Color(0xFF25F4EE),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              owner?.displayName ?? device.uid,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              device.deviceName ?? device.deviceId,
              style:
                  const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              device.lastSeenAt != null
                  ? _formatDate(device.lastSeenAt!)
                  : _formatDate(device.registeredAt),
              style:
                  const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          SizedBox(
            width: 80,
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              tooltip: '端末解除',
              onPressed: () => _confirmRemoveDevice(device),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _confirmRemoveDevice(DeviceRegistration device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('端末解除'),
        content: Text(
            '「${device.deviceName ?? device.deviceId}」を解除しますか？\nこの端末は再登録が必要になります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.instance.removeDevice(device.id);
              final admin = ref.read(adminAuthProvider).user;
              if (admin != null) {
                FirestoreService.instance.writeLog(
                  action: 'device_remove',
                  actorUid: admin.uid,
                  detail:
                      'Removed device: ${device.deviceName ?? device.deviceId} (${device.deviceType.name})',
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('端末を解除しました')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('解除'),
          ),
        ],
      ),
    );
  }
}
