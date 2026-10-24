import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/exceptions/backup_exceptions.dart';
import 'package:noteton/core/services/schema_validator.dart';

void main() {
  const validator = SchemaValidator();

  Map<String, dynamic> minimal() => {
        'version': 3,
        'songs': [
          {'id': 1, 'title': 'Brano', 'filePath': ''},
        ],
      };

  group('SchemaValidator', () {
    test('accetta un backup v3 minimale', () {
      expect(() => validator.validate(minimal()), returnsNormally);
    });

    test('accetta backup senza version (formato v1)', () {
      final data = minimal()..remove('version');
      expect(() => validator.validate(data), returnsNormally);
    });

    test('accetta liste opzionali vuote o assenti', () {
      final data = minimal()
        ..['setlists'] = []
        ..['collections'] = []
        ..['annotations'] = []
        ..['tags'] = []
        ..['songTags'] = [];
      expect(() => validator.validate(data), returnsNormally);
    });

    test('rifiuta una versione futura', () {
      final data = minimal()..['version'] = 4;
      expect(
        () => validator.validate(data),
        throwsA(isA<BackupVersionUnsupportedException>()
            .having((e) => e.version, 'version', 4)
            .having((e) => e.maxSupportedVersion, 'max', 3)),
      );
    });

    test('rifiuta version non intera', () {
      final data = minimal()..['version'] = '3';
      expect(
        () => validator.validate(data),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'version')),
      );
    });

    test('rifiuta songs mancante o non lista', () {
      expect(
        () => validator.validate({'version': 3}),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'songs')),
      );
      expect(
        () => validator.validate({'songs': 'x'}),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'songs')),
      );
    });

    test('indica il brano con id non valido', () {
      final data = {
        'songs': [
          {'id': 1, 'title': 'Ok'},
          {'id': '2', 'title': 'Id stringa'},
        ],
      };
      expect(
        () => validator.validate(data),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'songs[1].id')),
      );
    });

    test('indica il brano con titolo vuoto', () {
      final data = {
        'songs': [
          {'id': 1, 'title': ''},
        ],
      };
      expect(
        () => validator.validate(data),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'songs[0].title')),
      );
    });

    test('rifiuta un elemento di songs che non è un oggetto', () {
      expect(
        () => validator.validate({
          'songs': [42],
        }),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'songs[0]')),
      );
    });

    for (final field in [
      'setlists',
      'collections',
      'annotations',
      'tags',
      'songTags',
    ]) {
      test('rifiuta $field non lista', () {
        final data = minimal()..[field] = {'a': 1};
        expect(
          () => validator.validate(data),
          throwsA(isA<BackupSchemaInvalidException>()
              .having((e) => e.field, 'field', field)),
        );
      });
    }
  });
}
