import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/domain/models/song.dart';

Song _baseSong() => Song(
      id: 1,
      title: 'Sonata n.1',
      filePath: 'abc.pdf',
      totalPages: 10,
      lastPage: 3,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      status: SongStatus.ready,
      keySignature: 'D major',
      bpm: 120,
      instrument: 'Piano',
      composerId: 5,
    );

void main() {
  group('Song.copyWith', () {
    test('updates scalar fields correctly', () {
      final s = _baseSong().copyWith(title: 'Nuova', lastPage: 7);
      expect(s.title, 'Nuova');
      expect(s.lastPage, 7);
      expect(s.totalPages, 10); // invariato
    });

    test('clearKeySignature sets keySignature to null', () {
      final s = _baseSong().copyWith(clearKeySignature: true);
      expect(s.keySignature, isNull);
    });

    test('clearBpm sets bpm to null', () {
      final s = _baseSong().copyWith(clearBpm: true);
      expect(s.bpm, isNull);
    });

    test('clearInstrument sets instrument to null', () {
      final s = _baseSong().copyWith(clearInstrument: true);
      expect(s.instrument, isNull);
    });

    test('clearComposerId sets composerId to null', () {
      final s = _baseSong().copyWith(clearComposerId: true);
      expect(s.composerId, isNull);
    });

    test('without clear flags, nullable fields are preserved', () {
      final s = _baseSong().copyWith(title: 'Updated');
      expect(s.keySignature, 'D major');
      expect(s.bpm, 120);
      expect(s.instrument, 'Piano');
      expect(s.composerId, 5);
    });

    test('status is preserved when not specified', () {
      final s = _baseSong().copyWith(title: 'X');
      expect(s.status, SongStatus.ready);
    });
  });

  group('Song.fromMap / toMap', () {
    test('round-trip preserves all fields', () {
      final original = _baseSong();
      final map = original.toMap();
      // Simulate DB join result (composer_name from LEFT JOIN)
      map['composer_name'] = 'Mozart';
      final restored = Song.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.keySignature, original.keySignature);
      expect(restored.bpm, original.bpm);
      expect(restored.instrument, original.instrument);
      expect(restored.status, original.status);
      expect(restored.composerName, 'Mozart');
    });

    test('missing nullable fields default to null', () {
      final map = {
        'id': 2,
        'title': 'Test',
        'file_path': 'x.pdf',
        'total_pages': 0,
        'last_page': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'status': 'none',
      };
      final s = Song.fromMap(map);
      expect(s.keySignature, isNull);
      expect(s.bpm, isNull);
      expect(s.instrument, isNull);
      expect(s.composerId, isNull);
    });

    test('status round-trips for all values', () {
      for (final status in SongStatus.values) {
        final map = _baseSong().copyWith(status: status).toMap();
        final restored = Song.fromMap(map);
        expect(restored.status, status,
            reason: 'Status ${status.name} failed round-trip');
      }
    });
  });

  group('SongStatus', () {
    test('fromDb returns none for unknown value', () {
      expect(SongStatus.fromDb('bogus'), SongStatus.none);
      expect(SongStatus.fromDb(null), SongStatus.none);
    });

    test('all statuses have non-empty dbValue except none', () {
      for (final s in SongStatus.values) {
        expect(s.dbValue, isNotEmpty);
      }
    });
  });
}
