import 'song.dart';

class SetlistItem {
  final int? id;
  final int setlistId;
  final int songId;
  final int position;
  final int customStartPage;

  // Optional joined data
  final Song? song;

  const SetlistItem({
    this.id,
    required this.setlistId,
    required this.songId,
    required this.position,
    this.customStartPage = 0,
    this.song,
  });

  factory SetlistItem.fromMap(Map<String, dynamic> map) {
    return SetlistItem(
      id: map['id'] as int?,
      setlistId: map['setlist_id'] as int,
      songId: map['song_id'] as int,
      position: map['position'] as int,
      customStartPage: (map['custom_start_page'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'setlist_id': setlistId,
      'song_id': songId,
      'position': position,
      'custom_start_page': customStartPage,
    };
  }

  SetlistItem copyWith({
    int? id,
    int? setlistId,
    int? songId,
    int? position,
    int? customStartPage,
    Song? song,
  }) {
    return SetlistItem(
      id: id ?? this.id,
      setlistId: setlistId ?? this.setlistId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      customStartPage: customStartPage ?? this.customStartPage,
      song: song ?? this.song,
    );
  }
}
