class Tag {
  final int? id;
  final String name;
  final String color; // hex color, e.g. "#FF5733"

  const Tag({
    this.id,
    required this.name,
    required this.color,
  });

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
    };
  }

  Tag copyWith({int? id, String? name, String? color}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
