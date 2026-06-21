import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/database/database_helper.dart';
import 'package:noteton/data/repositories/song_repository.dart';
import 'package:noteton/data/repositories/tag_repository.dart';
import 'package:noteton/domain/models/song.dart';
import 'package:noteton/domain/models/tag.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_database.dart';

void main() {
  late SongRepository repo;

  setUp(() async {
    await openTestDatabase();
    repo = SongRepository();
  });

  Song song(
    String title, {
    int? composerId,
    String? album,
    String? period,
    String? keySignature,
    String? fileHash,
  }) =>
      Song(
        title: title,
        composerId: composerId,
        filePath: 'pdfs/${title.toLowerCase()}.pdf',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        album: album,
        period: period,
        keySignature: keySignature,
        fileHash: fileHash,
      );

  group('SongRepository CRUD', () {
    test('insert assegna id e getById lo ritrova', () async {
      final inserted = await repo.insert(song('Preludio'));
      expect(inserted.id, isNotNull);
      expect((await repo.getById(inserted.id!))!.title, 'Preludio');
    });

    test('getById restituisce null se assente', () async {
      expect(await repo.getById(999), isNull);
    });

    test('getById popola composerName via JOIN', () async {
      final db = await DatabaseHelper.instance.database;
      final composerId = await insertComposer(db, name: 'Chopin');
      final inserted = await repo.insert(song('Notturno', composerId: composerId));

      expect((await repo.getById(inserted.id!))!.composerName, 'Chopin');
    });

    test('update modifica i campi', () async {
      final inserted = await repo.insert(song('Bozza'));
      await repo.update(inserted.copyWith(title: 'Definitivo', album: 'Op. 1'));

      final fetched = await repo.getById(inserted.id!);
      expect(fetched!.title, 'Definitivo');
      expect(fetched.album, 'Op. 1');
    });

    test('updateLastPage aggiorna last_page', () async {
      final inserted = await repo.insert(song('Sonata'));
      await repo.updateLastPage(inserted.id!, 7);
      expect((await repo.getById(inserted.id!))!.lastPage, 7);
    });
  });

  group('SongRepository query', () {
    test('getAll ordina per titolo ASC', () async {
      await repo.insert(song('Zeta'));
      await repo.insert(song('Alfa'));

      final titles = (await repo.getAll()).map((s) => s.title).toList();
      expect(titles, ['Alfa', 'Zeta']);
    });

    test('getAll con searchQuery filtra su titolo/album/period/tonalità',
        () async {
      await repo.insert(song('Improvviso', album: 'Raccolta Blu'));
      await repo.insert(song('Studio', period: 'Romantico'));
      await repo.insert(song('Marcia', keySignature: 'Do maggiore'));

      expect((await repo.getAll(searchQuery: 'Improvviso')).length, 1);
      expect((await repo.getAll(searchQuery: 'Blu')).single.title, 'Improvviso');
      expect((await repo.getAll(searchQuery: 'Romantico')).single.title, 'Studio');
      expect((await repo.getAll(searchQuery: 'Do mag')).single.title, 'Marcia');
      expect((await repo.getAll(searchQuery: 'inesistente')), isEmpty);
    });

    test('getAll con tagId filtra per tag', () async {
      final a = await repo.insert(song('Con tag'));
      await repo.insert(song('Senza tag'));
      final tagRepo = TagRepository();
      final tag = await tagRepo.insert(const Tag(name: 'Studio', color: '#000'));
      await repo.setTagsForSong(a.id!, [tag.id!]);

      final filtered = await repo.getAll(tagId: tag.id);
      expect(filtered.map((s) => s.title), ['Con tag']);
    });

    test('getByComposerId restituisce i brani del compositore', () async {
      final db = await DatabaseHelper.instance.database;
      final composerId = await insertComposer(db, name: 'Bach');
      await repo.insert(song('BWV 1', composerId: composerId));
      await repo.insert(song('BWV 2', composerId: composerId));
      await repo.insert(song('Altro'));

      final byComposer = await repo.getByComposerId(composerId);
      expect(byComposer.map((s) => s.title), ['BWV 1', 'BWV 2']);
    });

    test('getByHash trova il brano con quell\'hash', () async {
      await repo.insert(song('Con hash', fileHash: 'abc123'));
      await repo.insert(song('Senza hash'));

      expect((await repo.getByHash('abc123'))!.title, 'Con hash');
      expect(await repo.getByHash('xxx'), isNull);
    });

    test('findAlbumsByPrefix restituisce album distinti per prefisso', () async {
      await repo.insert(song('A', album: 'Goldberg'));
      await repo.insert(song('B', album: 'Goldberg')); // duplicato
      await repo.insert(song('C', album: 'Gymnopedies'));
      await repo.insert(song('D', album: 'Nocturnes'));

      final albums = await repo.findAlbumsByPrefix('go');
      expect(albums, ['Goldberg']); // distinct + filtrato per prefisso
    });

    test('findAlbumsByPrefix con stringa vuota restituisce lista vuota',
        () async {
      await repo.insert(song('A', album: 'Goldberg'));
      expect(await repo.findAlbumsByPrefix(''), isEmpty);
    });
  });

  group('SongRepository tags', () {
    test('setTagsForSong e getTagsForSong (transazione)', () async {
      final inserted = await repo.insert(song('Brano'));
      final tagRepo = TagRepository();
      final jazz = await tagRepo.insert(const Tag(name: 'Jazz', color: '#000'));
      final rock = await tagRepo.insert(const Tag(name: 'Rock', color: '#111'));

      await repo.setTagsForSong(inserted.id!, [jazz.id!, rock.id!]);
      var tags = await repo.getTagsForSong(inserted.id!);
      expect(tags.map((t) => t.name).toSet(), {'Jazz', 'Rock'});

      // Sostituzione
      await repo.setTagsForSong(inserted.id!, [jazz.id!]);
      tags = await repo.getTagsForSong(inserted.id!);
      expect(tags.map((t) => t.name), ['Jazz']);
    });
  });
}
