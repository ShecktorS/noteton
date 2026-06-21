import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/database/database_helper.dart';
import 'package:noteton/data/repositories/tag_repository.dart';
import 'package:noteton/domain/models/tag.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_database.dart';

void main() {
  late TagRepository repo;

  setUp(() async {
    await openTestDatabase();
    repo = TagRepository();
  });

  Tag tag(String name, [String color = '#FF0000']) =>
      Tag(name: name, color: color);

  group('TagRepository CRUD', () {
    test('insert assegna un id e getAll restituisce il tag', () async {
      final inserted = await repo.insert(tag('Jazz'));
      expect(inserted.id, isNotNull);

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.name, 'Jazz');
      expect(all.first.color, '#FF0000');
    });

    test('getAll ordina per nome ASC', () async {
      await repo.insert(tag('Rock'));
      await repo.insert(tag('Blues'));
      await repo.insert(tag('Pop'));

      final names = (await repo.getAll()).map((t) => t.name).toList();
      expect(names, ['Blues', 'Pop', 'Rock']);
    });

    test('update modifica nome e colore', () async {
      final inserted = await repo.insert(tag('Provvisorio'));
      await repo.update(inserted.copyWith(name: 'Definitivo', color: '#00FF00'));

      final all = await repo.getAll();
      expect(all.single.name, 'Definitivo');
      expect(all.single.color, '#00FF00');
    });

    test('delete rimuove il tag', () async {
      final inserted = await repo.insert(tag('Temporaneo'));
      await repo.delete(inserted.id!);
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('TagRepository associazioni song_tags', () {
    test('getTagsForSong restituisce solo i tag del brano', () async {
      final db = await DatabaseHelper.instance.database;
      final songId = await insertSong(db);
      final otherSongId = await insertSong(db, title: 'Altro');

      final jazz = await repo.insert(tag('Jazz'));
      final rock = await repo.insert(tag('Rock'));
      final pop = await repo.insert(tag('Pop'));

      await repo.setTagsForSong(songId, [jazz.id!, rock.id!]);
      await repo.setTagsForSong(otherSongId, [pop.id!]);

      final tags = await repo.getTagsForSong(songId);
      expect(tags.map((t) => t.name), ['Jazz', 'Rock']); // ordinati per nome
    });

    test('setTagsForSong sostituisce le associazioni precedenti', () async {
      final db = await DatabaseHelper.instance.database;
      final songId = await insertSong(db);

      final a = await repo.insert(tag('A'));
      final b = await repo.insert(tag('B'));
      final c = await repo.insert(tag('C'));

      await repo.setTagsForSong(songId, [a.id!, b.id!]);
      await repo.setTagsForSong(songId, [c.id!]);

      final tags = await repo.getTagsForSong(songId);
      expect(tags.map((t) => t.name), ['C']);
    });

    test('setTagsForSong con lista vuota rimuove tutte le associazioni',
        () async {
      final db = await DatabaseHelper.instance.database;
      final songId = await insertSong(db);
      final a = await repo.insert(tag('A'));

      await repo.setTagsForSong(songId, [a.id!]);
      await repo.setTagsForSong(songId, []);

      expect(await repo.getTagsForSong(songId), isEmpty);
    });

    test('eliminando un tag, le righe song_tags spariscono (CASCADE)',
        () async {
      final db = await DatabaseHelper.instance.database;
      final songId = await insertSong(db);
      final a = await repo.insert(tag('A'));
      await repo.setTagsForSong(songId, [a.id!]);

      await repo.delete(a.id!);

      final rows = await db.query('song_tags', where: 'tag_id = ?',
          whereArgs: [a.id]);
      expect(rows, isEmpty);
    });

    test('eliminando un brano, le righe song_tags spariscono (CASCADE)',
        () async {
      final db = await DatabaseHelper.instance.database;
      final songId = await insertSong(db);
      final a = await repo.insert(tag('A'));
      await repo.setTagsForSong(songId, [a.id!]);

      await db.delete('songs', where: 'id = ?', whereArgs: [songId]);

      final rows = await db.query('song_tags', where: 'song_id = ?',
          whereArgs: [songId]);
      expect(rows, isEmpty);
      // Il tag resta: solo l'associazione viene rimossa.
      expect((await repo.getAll()).length, 1);
    });
  });
}
