import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/repositories/composer_repository.dart';
import 'package:noteton/domain/models/composer.dart';

import '../helpers/test_database.dart';

void main() {
  late ComposerRepository repo;

  setUp(() async {
    await openTestDatabase();
    repo = ComposerRepository();
  });

  group('ComposerRepository CRUD', () {
    test('insert assegna id e getById lo ritrova', () async {
      final inserted =
          await repo.insert(const Composer(name: 'Bach', bornYear: 1685));
      expect(inserted.id, isNotNull);

      final fetched = await repo.getById(inserted.id!);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Bach');
      expect(fetched.bornYear, 1685);
    });

    test('getById restituisce null se assente', () async {
      expect(await repo.getById(999), isNull);
    });

    test('getAll ordina per nome ASC', () async {
      await repo.insert(const Composer(name: 'Mozart'));
      await repo.insert(const Composer(name: 'Albinoni'));

      final names = (await repo.getAll()).map((c) => c.name).toList();
      expect(names, ['Albinoni', 'Mozart']);
    });

    test('update modifica i campi', () async {
      final inserted = await repo.insert(const Composer(name: 'Anon'));
      await repo
          .update(inserted.copyWith(name: 'Vivaldi', bornYear: 1678));

      final fetched = await repo.getById(inserted.id!);
      expect(fetched!.name, 'Vivaldi');
      expect(fetched.bornYear, 1678);
    });

    test('delete rimuove il compositore', () async {
      final inserted = await repo.insert(const Composer(name: 'Tmp'));
      await repo.delete(inserted.id!);
      expect(await repo.getById(inserted.id!), isNull);
    });
  });

  group('ComposerRepository lookup', () {
    test('findByName è case-insensitive', () async {
      await repo.insert(const Composer(name: 'Beethoven'));

      expect((await repo.findByName('beethoven'))?.name, 'Beethoven');
      expect((await repo.findByName('BEETHOVEN'))?.name, 'Beethoven');
      expect(await repo.findByName('inesistente'), isNull);
    });

    test('findByPrefix filtra per prefisso, case-insensitive, e rispetta limit',
        () async {
      await repo.insert(const Composer(name: 'Chopin'));
      await repo.insert(const Composer(name: 'Chausson'));
      await repo.insert(const Composer(name: 'Cherubini'));
      await repo.insert(const Composer(name: 'Bach'));

      final ch = await repo.findByPrefix('ch');
      expect(ch.map((c) => c.name), ['Chausson', 'Cherubini', 'Chopin']);

      final limited = await repo.findByPrefix('ch', limit: 2);
      expect(limited.length, 2);
    });

    test('findByPrefix con stringa vuota restituisce lista vuota', () async {
      await repo.insert(const Composer(name: 'Bach'));
      expect(await repo.findByPrefix(''), isEmpty);
    });

    test('findOrCreate crea se assente e riusa se presente', () async {
      final created = await repo.findOrCreate('Liszt');
      expect(created.id, isNotNull);

      final reused = await repo.findOrCreate('liszt'); // case-insensitive
      expect(reused.id, created.id);
      expect((await repo.getAll()).length, 1);
    });
  });
}
