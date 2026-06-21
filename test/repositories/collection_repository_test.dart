import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/database/database_helper.dart';
import 'package:noteton/data/repositories/collection_repository.dart';
import 'package:noteton/domain/models/collection.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_database.dart';

void main() {
  late CollectionRepository repo;

  setUp(() async {
    await openTestDatabase();
    repo = CollectionRepository();
  });

  Collection collection(String name, {String color = '#2196F3'}) =>
      Collection(name: name, color: color, createdAt: DateTime(2024, 1, 1));

  group('CollectionRepository CRUD', () {
    test('insert assegna id e getById lo ritrova', () async {
      final inserted = await repo.insert(collection('Studi'));
      expect(inserted.id, isNotNull);

      final fetched = await repo.getById(inserted.id!);
      expect(fetched!.name, 'Studi');
      expect(fetched.songCount, 0);
    });

    test('getById restituisce null se assente', () async {
      expect(await repo.getById(999), isNull);
    });

    test('getAll ordina per nome (NOCASE)', () async {
      await repo.insert(collection('zeta'));
      await repo.insert(collection('Alfa'));

      final names = (await repo.getAll()).map((c) => c.name).toList();
      expect(names, ['Alfa', 'zeta']);
    });

    test('update modifica nome e colore', () async {
      final inserted = await repo.insert(collection('Bozza'));
      await repo.update(inserted.copyWith(name: 'Finale', color: '#FF0000'));

      final fetched = await repo.getById(inserted.id!);
      expect(fetched!.name, 'Finale');
      expect(fetched.color, '#FF0000');
    });

    test('delete rimuove la raccolta', () async {
      final inserted = await repo.insert(collection('Tmp'));
      await repo.delete(inserted.id!);
      expect(await repo.getById(inserted.id!), isNull);
    });
  });

  group('CollectionRepository brani', () {
    late int collectionId;
    late int songAId;
    late int songBId;

    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      songAId = await insertSong(db, title: 'Alfa');
      songBId = await insertSong(db, title: 'Beta');
      final c = await repo.insert(collection('Mista'));
      collectionId = c.id!;
    });

    test('song_count riflette i brani aggiunti', () async {
      await repo.addSong(collectionId, songAId);
      await repo.addSong(collectionId, songBId);

      expect((await repo.getById(collectionId))!.songCount, 2);
      expect((await repo.getAll()).single.songCount, 2);
    });

    test('addSong è idempotente (ConflictAlgorithm.ignore)', () async {
      await repo.addSong(collectionId, songAId);
      await repo.addSong(collectionId, songAId);

      expect((await repo.getById(collectionId))!.songCount, 1);
    });

    test('removeSong scollega il brano', () async {
      await repo.addSong(collectionId, songAId);
      await repo.removeSong(collectionId, songAId);

      expect((await repo.getById(collectionId))!.songCount, 0);
    });

    test('getSongs restituisce i brani ordinati per titolo', () async {
      await repo.addSong(collectionId, songBId);
      await repo.addSong(collectionId, songAId);

      final titles = (await repo.getSongs(collectionId))
          .map((s) => s.title)
          .toList();
      expect(titles, ['Alfa', 'Beta']);
    });

    test('getCollectionIdsForSong elenca le raccolte di un brano', () async {
      final other = await repo.insert(collection('Altra'));
      await repo.addSong(collectionId, songAId);
      await repo.addSong(other.id!, songAId);

      final ids = await repo.getCollectionIdsForSong(songAId);
      expect(ids.toSet(), {collectionId, other.id});
    });

    test('delete della raccolta rimuove song_collections (CASCADE)', () async {
      await repo.addSong(collectionId, songAId);
      await repo.delete(collectionId);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('song_collections',
          where: 'collection_id = ?', whereArgs: [collectionId]);
      expect(rows, isEmpty);
    });
  });
}
