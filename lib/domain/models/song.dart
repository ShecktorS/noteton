import 'package:flutter/material.dart';

enum SongStatus {
  none,
  toLearn,
  inProgress,
  ready,
  repertoire;

  String get label {
    switch (this) {
      case SongStatus.none: return '';
      case SongStatus.toLearn: return 'Da imparare';
      case SongStatus.inProgress: return 'In studio';
      case SongStatus.ready: return 'Pronto';
      case SongStatus.repertoire: return 'In repertorio';
    }
  }

  String get dbValue {
    switch (this) {
      case SongStatus.none: return 'none';
      case SongStatus.toLearn: return 'to_learn';
      case SongStatus.inProgress: return 'in_progress';
      case SongStatus.ready: return 'ready';
      case SongStatus.repertoire: return 'repertoire';
    }
  }

  static SongStatus fromDb(String? value) {
    switch (value) {
      case 'to_learn': return SongStatus.toLearn;
      case 'in_progress': return SongStatus.inProgress;
      case 'ready': return SongStatus.ready;
      case 'repertoire': return SongStatus.repertoire;
      default: return SongStatus.none;
    }
  }

  Color get color {
    switch (this) {
      case SongStatus.none: return Colors.transparent;
      case SongStatus.toLearn: return const Color(0xFF9E9E9E);    // grigio
      case SongStatus.inProgress: return const Color(0xFF2196F3); // blu
      case SongStatus.ready: return const Color(0xFF4CAF50);      // verde
      case SongStatus.repertoire: return const Color(0xFFD4A853); // dorato
    }
  }
}

class Song {
  final int? id;
  final String title;
  final int? composerId;
  final String filePath;
  final int totalPages;
  final int lastPage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SongStatus status;
  final String? keySignature;
  final int? bpm;
  final String? instrument;
  final String? album;
  final String? period;
  final String? fileHash; // SHA-256 of the PDF file — used for duplicate detection

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
    this.status = SongStatus.none,
    this.keySignature,
    this.bpm,
    this.instrument,
    this.album,
    this.period,
    this.fileHash,
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
      status: SongStatus.fromDb(map['status'] as String?),
      keySignature: map['key_signature'] as String?,
      bpm: map['bpm'] as int?,
      instrument: map['instrument'] as String?,
      album: map['album'] as String?,
      period: map['period'] as String?,
      fileHash: map['file_hash'] as String?,
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
      'status': status.dbValue,
      'key_signature': keySignature,
      'bpm': bpm,
      'instrument': instrument,
      'album': album,
      'period': period,
      'file_hash': fileHash,
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
    SongStatus? status,
    String? keySignature,
    int? bpm,
    String? instrument,
    String? album,
    String? period,
    String? fileHash,
    String? composerName,
    List<String>? tags,
    // Sentinel per azzerare valori nullable
    bool clearKeySignature = false,
    bool clearBpm = false,
    bool clearInstrument = false,
    bool clearAlbum = false,
    bool clearPeriod = false,
    bool clearComposerId = false,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      composerId: clearComposerId ? null : composerId ?? this.composerId,
      filePath: filePath ?? this.filePath,
      totalPages: totalPages ?? this.totalPages,
      lastPage: lastPage ?? this.lastPage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      keySignature: clearKeySignature ? null : keySignature ?? this.keySignature,
      bpm: clearBpm ? null : bpm ?? this.bpm,
      instrument: clearInstrument ? null : instrument ?? this.instrument,
      album: clearAlbum ? null : album ?? this.album,
      period: clearPeriod ? null : period ?? this.period,
      fileHash: fileHash ?? this.fileHash,
      composerName: composerName ?? this.composerName,
      tags: tags ?? this.tags,
    );
  }
}
