import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Sostituisce `path_provider` con cartelle temporanee reali, così i test
/// possono esercitare codice che scrive su filesystem (backup, import MSB,
/// checkpoint) senza platform channel.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final Directory root;

  FakePathProvider(this.root);

  String get documentsPath => p.join(root.path, 'docs');
  String get temporaryPath => p.join(root.path, 'tmp');

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;

  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root.path, 'support');
}

/// Installa un [FakePathProvider] su una cartella temporanea nuova, che
/// viene cancellata a fine test. Da chiamare dentro `setUp`.
Future<FakePathProvider> installFakePathProvider() async {
  final root = await Directory.systemTemp.createTemp('noteton_test_');
  final fake = FakePathProvider(root);
  await Directory(fake.documentsPath).create(recursive: true);
  await Directory(fake.temporaryPath).create(recursive: true);
  PathProviderPlatform.instance = fake;
  addTearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  return fake;
}
