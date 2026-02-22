class MixPreset {
  final String id;
  String name;
  double clipGain;
  double bgmGain;

  MixPreset({
    required this.id,
    required this.name,
    this.clipGain = 1.0,
    this.bgmGain = 0.3,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clipGain': clipGain,
        'bgmGain': bgmGain,
      };

  factory MixPreset.fromJson(Map<String, dynamic> json) => MixPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        clipGain: (json['clipGain'] as num?)?.toDouble() ?? 1.0,
        bgmGain: (json['bgmGain'] as num?)?.toDouble() ?? 0.3,
      );
}
