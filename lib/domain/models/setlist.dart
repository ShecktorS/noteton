class Setlist {
  final int? id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? performanceDate;

  const Setlist({
    this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.performanceDate,
  });

  factory Setlist.fromMap(Map<String, dynamic> map) {
    return Setlist(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      performanceDate: map['performance_date'] != null
          ? DateTime.parse(map['performance_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'performance_date': performanceDate?.toIso8601String(),
    };
  }

  Setlist copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? performanceDate,
  }) {
    return Setlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      performanceDate: performanceDate ?? this.performanceDate,
    );
  }
}
