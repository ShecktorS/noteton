import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/database/database_helper.dart';
import 'package:noteton/data/repositories/setlist_repository.dart';
import 'package:noteton/domain/models/setlist.dart';
import 'package:noteton/domain/models/setlist_item.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_database.dart';

void main() {
  late SetlistRepository repo;

  setUp(() async {
    await openTestDatabase();
    repo = SetlistRepository();
  });

  Setlist setlist(String title, DateTime createdAt) =>
      Setlist(title: title, createdAt: createdAt);

  group('SetlistRepository CRUD', () {
    test('insert assegna id e getById lo ritrova', () async {
      final inserted =
          await repo.insert(setlist('Concerto', DateTime(2024, 5, 1)));
      expect(inserted.id, isNotNull);
      expect((await repo.getById(inserted.id!))!.title, 'Concerto');
    });

    test('getById restituisce null se assente', () async {
      expect(await repo.getById(999), isNull);
    });

    test('getAll ordina per created_at DESC', () async {
      await repo.insert(setlist('Vecchia', DateTime(2024, 1, 1)));
      await repo.insert(setlist('Nuova', DateTime(2024, 12, 31)));
      await repo.insert(setlist('Media', DateTime(2024, 6, 15)));

      final titles = (await repo.getAll()).map((s) => s.title).toList();
      expect(titles, ['Nuova', 'Media', 'Vecchia']);
    });

    test('update modifica il titolo', () async {
      final inserted = await repo.insert(setlist('Bozza', DateTime(2024, 1, 1)));
      await repo.update(inserted.copyWith(title: 'Definitiva'));
      expect((await repo.getById(inserted.id!))!.title, 'Definitiva');
    });

    test('delete rimuove la setlist', () async {
      final inserted = await repo.insert(setlist('Tmp', DateTime(2024, 1, 1)));
      await repo.delete(inserted.id!);
      expect(await repo.getById(inserted.id!), isNull);
    });
  });

  group('SetlistRepository items', () {
    late int setlistId;
    late int songAId;
    late int songBId;

    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      final composerId = await insertComposer(db, name: 'Bach');
      songAId = await insertSong(db, title: 'Aria', composerId: composerId);
      songBId = await insertSong(db, title: 'Badinerie');
      final s = await repo.insert(setlist('Live', DateTime(2024, 1, 1)));
      setlistId = s.id!;
    });

    test('addItem e getItemCount', () async {
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songAId, position: 0));
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songBId, position: 1));

      expect(await repo.getItemCount(setlistId), 2);
    });

    test('getItemsForSetlist popola il brano e il compositore via JOIN',
        () async {
      await repo.addItem(SetlistItem(
          setlistId: setlistId,
          songId: songAId,
          position: 0,
          customStartPage: 3));

      final items = await repo.getItemsForSetlist(setlistId);
      expect(items.length, 1);
      expect(items.first.customStartPage, 3);
      expect(items.first.song, isNotNull);
      expect(items.first.song!.title, 'Aria');
      expect(items.first.song!.composerName, 'Bach');
    });

    test('getItemsForSetlist ordina per position ASC', () async {
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songAId, position: 1));
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songBId, position: 0));

      final titles = (await repo.getItemsForSetlist(setlistId))
          .map((i) => i.song!.title)
          .toList();
      expect(titles, ['Badinerie', 'Aria']);
    });

    test('removeItem elimina un singolo item', () async {
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songAId, position: 0));
      final itemId =
          (await repo.getItemsForSetlist(setlistId)).first.id!;

      await repo.removeItem(itemId);
      expect(await repo.getItemCount(setlistId), 0);
    });

    test('reorderItems riscrive le posizioni in ordine (transazione)',
        () async {
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songAId, position: 0));
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songBId, position: 1));

      final items = await repo.getItemsForSetlist(setlistId);
      // Inverti l'ordine e riordina.
      await repo.reorderItems(setlistId, items.reversed.toList());

      final reordered = await repo.getItemsForSetlist(setlistId);
      expect(reordered.map((i) => i.song!.title), ['Badinerie', 'Aria']);
      expect(reordered.map((i) => i.position), [0, 1]);
    });

    test('delete della setlist rimuove gli item (CASCADE)', () async {
      await repo.addItem(
          SetlistItem(setlistId: setlistId, songId: songAId, position: 0));

      await repo.delete(setlistId);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('setlist_items',
          where: 'setlist_id = ?', whereArgs: [setlistId]);
      expect(rows, isEmpty);
    });
  });
}
