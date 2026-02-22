/// Message delivered by admin to users
class AppMessage {
  final String id;
  final String body;
  final MessagePriority priority;
  final MessageTarget target;
  final String? targetValue; // group name, uid, role
  final DateTime createdAt;
  final String createdBy; // admin uid

  const AppMessage({
    required this.id,
    required this.body,
    this.priority = MessagePriority.normal,
    this.target = MessageTarget.all,
    this.targetValue,
    required this.createdAt,
    required this.createdBy,
  });

  bool get isUrgent => priority == MessagePriority.urgent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'priority': priority.name,
        'target': target.name,
        'targetValue': targetValue,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory AppMessage.fromJson(Map<String, dynamic> json) => AppMessage(
        id: json['id'] as String,
        body: json['body'] as String,
        priority: MessagePriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => MessagePriority.normal,
        ),
        target: MessageTarget.values.firstWhere(
          (e) => e.name == json['target'],
          orElse: () => MessageTarget.all,
        ),
        targetValue: json['targetValue'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

enum MessagePriority { normal, urgent }

enum MessageTarget { all, individual, group, role }
