class Collection {
  final int? id;
  final String name;
  final String? description;
  final String color; // hex e.g. "#2196F3"
  final DateTime createdAt;
  final int songCount; // transient, from JOIN

  const Collection({
    this.id,
    required this.name,
    this.description,
    required this.color,
    required this.createdAt,
    this.songCount = 0,
  });

  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      songCount: (map['song_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (description != null) 'description': description,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Collection copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    int? songCount,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      songCount: songCount ?? this.songCount,
    );
  }
}
