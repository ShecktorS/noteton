class Song {
  final int? id;
  final String title;
  final int? composerId;
  final String filePath;
  final int totalPages;
  final int lastPage;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional joined data (not stored in songs table directly)
  final String? composerName;
  final List<String> tags;

  const Song({
    this.id,
    required this.title,
    this.composerId,
    required this.filePath,
    this.totalPages = 0,
    this.lastPage = 0,
    required this.createdAt,
    required this.updatedAt,
    this.composerName,
    this.tags = const [],
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as int?,
      title: map['title'] as String,
      composerId: map['composer_id'] as int?,
      filePath: map['file_path'] as String,
      totalPages: (map['total_pages'] as int?) ?? 0,
      lastPage: (map['last_page'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      composerName: map['composer_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'composer_id': composerId,
      'file_path': filePath,
      'total_pages': totalPages,
      'last_page': lastPage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Song copyWith({
    int? id,
    String? title,
    int? composerId,
    String? filePath,
    int? totalPages,
    int? lastPage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? composerName,
    List<String>? tags,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      composerId: composerId ?? this.composerId,
      filePath: filePath ?? this.filePath,
      totalPages: totalPages ?? this.totalPages,
      lastPage: lastPage ?? this.lastPage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      composerName: composerName ?? this.composerName,
      tags: tags ?? this.tags,
    );
  }
}
