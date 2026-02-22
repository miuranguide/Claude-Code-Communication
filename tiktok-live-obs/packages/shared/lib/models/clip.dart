import 'layout_data.dart';

enum ClipCategory { win, lose, other }

class Clip {
  final String id;
  String name;
  ClipCategory category;
  String filePath;
  int durationMs;
  LayoutData layout;
  int cooldownMs;
  String? thumbnailPath;

  Clip({
    required this.id,
    required this.name,
    this.category = ClipCategory.other,
    required this.filePath,
    this.durationMs = 0,
    LayoutData? layout,
    this.cooldownMs = 3000,
    this.thumbnailPath,
  }) : layout = layout ?? LayoutData();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'filePath': filePath,
        'durationMs': durationMs,
        'layout': layout.toJson(),
        'cooldownMs': cooldownMs,
        'thumbnailPath': thumbnailPath,
      };

  factory Clip.fromJson(Map<String, dynamic> json) => Clip(
        id: json['id'] as String,
        name: json['name'] as String,
        category: ClipCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => ClipCategory.other,
        ),
        filePath: json['filePath'] as String,
        durationMs: json['durationMs'] as int? ?? 0,
        layout: json['layout'] != null
            ? LayoutData.fromJson(json['layout'] as Map<String, dynamic>)
            : null,
        cooldownMs: json['cooldownMs'] as int? ?? 3000,
        thumbnailPath: json['thumbnailPath'] as String?,
      );
}
