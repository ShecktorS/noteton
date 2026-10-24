import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/utils/song_path.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory docs;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('song_path_test');
    docs = await Directory(p.join(root.path, 'docs')).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docs.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await root.delete(recursive: true);
  });

  test('risolve un path relativo dentro la docs dir', () async {
    await File(p.join(docs.path, 'a.pdf')).writeAsString('pdf');
    final r = await SongPath.resolveDetailed('a.pdf');
    expect(r.exists, isTrue);
    expect(r.reason, 'relative');
  });

  test('non risolve un path relativo che esce dalla docs dir', () async {
    await File(p.join(root.path, 'noteton.db')).writeAsString('db');
    final r = await SongPath.resolveDetailed('../noteton.db');
    expect(r.exists, isFalse);
  });

  test('risolve un path assoluto legacy solo se è un PDF', () async {
    final pdf = File(p.join(root.path, 'legacy.pdf'))..writeAsStringSync('x');
    final db = File(p.join(root.path, 'noteton.db'))..writeAsStringSync('x');

    final legacy = await SongPath.resolveDetailed(pdf.path);
    expect(legacy.exists, isTrue);
    expect(legacy.reason, 'absolute');

    final other = await SongPath.resolveDetailed(db.path);
    expect(other.exists, isFalse);
  });
}
