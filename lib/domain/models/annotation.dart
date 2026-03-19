class Annotation {
  final int? id;
  final int songId;
  final int pageNumber;
  final String annotationData; // JSON blob con percorsi SVG
  final DateTime createdAt;

  const Annotation({
    this.id,
    required this.songId,
    required this.pageNumber,
    required this.annotationData,
    required this.createdAt,
  });

  factory Annotation.fromMap(Map<String, dynamic> map) {
    return Annotation(
      id: map['id'] as int?,
      songId: map['song_id'] as int,
      pageNumber: map['page_number'] as int,
      annotationData: map['annotation_data'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'song_id': songId,
      'page_number': pageNumber,
      'annotation_data': annotationData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Annotation copyWith({
    int? id,
    int? songId,
    int? pageNumber,
    String? annotationData,
    DateTime? createdAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      pageNumber: pageNumber ?? this.pageNumber,
      annotationData: annotationData ?? this.annotationData,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
