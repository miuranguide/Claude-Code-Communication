/// User account managed by ラクガキ企画 admin
class AppUser {
  final String uid;
  final String loginId;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'member' | 'admin'
  final String? group;
  final bool isActive;
  final DateTime? activationDate;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.loginId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'member',
    this.group,
    this.isActive = true,
    this.activationDate,
    required this.createdAt,
  });

  bool get isActivated {
    if (!isActive) return false;
    if (activationDate == null) return true; // immediate activation
    return DateTime.now().isAfter(activationDate!);
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'loginId': loginId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'role': role,
        'group': group,
        'isActive': isActive,
        'activationDate': activationDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        loginId: json['loginId'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String? ?? 'member',
        group: json['group'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        activationDate: json['activationDate'] != null
            ? DateTime.parse(json['activationDate'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
