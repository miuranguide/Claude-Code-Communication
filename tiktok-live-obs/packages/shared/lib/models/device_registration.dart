/// Device registration for per-user device limits
class DeviceRegistration {
  final String id;
  final String uid; // owner user uid
  final DeviceType deviceType;
  final String deviceId; // unique device fingerprint
  final String? deviceName;
  final DateTime registeredAt;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const DeviceRegistration({
    required this.id,
    required this.uid,
    required this.deviceType,
    required this.deviceId,
    this.deviceName,
    required this.registeredAt,
    this.isOnline = false,
    this.lastSeenAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'deviceType': deviceType.name,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'registeredAt': registeredAt.toIso8601String(),
        'isOnline': isOnline,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
      };

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) =>
      DeviceRegistration(
        id: json['id'] as String,
        uid: json['uid'] as String,
        deviceType: DeviceType.values.firstWhere(
          (e) => e.name == json['deviceType'],
          orElse: () => DeviceType.controller,
        ),
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String?,
        registeredAt: DateTime.parse(json['registeredAt'] as String),
        isOnline: json['isOnline'] as bool? ?? false,
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.parse(json['lastSeenAt'] as String)
            : null,
      );
}

enum DeviceType { controller, display }
