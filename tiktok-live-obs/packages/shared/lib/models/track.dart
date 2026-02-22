class Track {
  final String id;
  String name;
  String filePath;
  double defaultGain;
  bool loop;
  int durationMs;

  Track({
    required this.id,
    required this.name,
    required this.filePath,
    this.defaultGain = 1.0,
    this.loop = true,
    this.durationMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'defaultGain': defaultGain,
        'loop': loop,
        'durationMs': durationMs,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        name: json['name'] as String,
        filePath: json['filePath'] as String,
        defaultGain: (json['defaultGain'] as num?)?.toDouble() ?? 1.0,
        loop: json['loop'] as bool? ?? true,
        durationMs: json['durationMs'] as int? ?? 0,
      );

  Track copyWith({
    String? name,
    String? filePath,
    double? defaultGain,
    bool? loop,
    int? durationMs,
  }) =>
      Track(
        id: id,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        defaultGain: defaultGain ?? this.defaultGain,
        loop: loop ?? this.loop,
        durationMs: durationMs ?? this.durationMs,
      );
}
