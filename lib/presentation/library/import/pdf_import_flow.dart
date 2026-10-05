import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/song_path.dart';
import '../../../domain/models/setlist_item.dart';
import '../../../domain/models/song.dart';
import '../../../providers/providers.dart';
import 'import_details_dialog.dart';

/// Flusso del pulsante `+` della libreria: sceglie uno o più PDF e li
/// importa. Con un solo file chiede se personalizzare titolo, autore,
/// setlist e raccolte; con più file importa tutto saltando i duplicati.
Future<void> startPdfImport(BuildContext context, WidgetRef ref) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Importazione PDF non disponibile su web. Usa la app mobile.')),
    );
    return;
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    allowMultiple: true,
  );
  if (result == null || result.files.isEmpty) return;
  if (!context.mounted) return;

  // ── Batch import (2+ files) ─────────────────────────────────────────────
  if (result.files.length > 1) {
    await _importBatch(context, ref, result.files);
    return;
  }

  // ── Single import (existing flow) ───────────────────────────────────────
  final picked = result.files.first;
  if (picked.path == null) return;

  final customize = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Importa spartito'),
      content: const Text(
          'Vuoi importare subito o aggiungere titolo, autore e lista?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Importa subito')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Personalizza')),
      ],
    ),
  );
  if (customize == null || !context.mounted) return;

  ImportDetails? importResult;
  if (customize) {
    importResult = await showDialog<ImportDetails>(
      context: context,
      builder: (ctx) => ImportDetailsDialog(
        defaultTitle: p.basenameWithoutExtension(picked.name),
      ),
    );
    if (importResult == null || !context.mounted) return;
  }

  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Importazione in corso…')));

  try {
    // ── Hash check for duplicates ───────────────────────────────────────
    final fileHash = await _computeHash(picked.path!);
    if (context.mounted && fileHash != null) {
      final existing =
          await ref.read(songRepositoryProvider).getByHash(fileHash);
      if (existing != null && context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('File già presente'),
            content: Text(
                'Questo PDF è già in libreria come:\n"${existing.title}"\n\nImportarlo comunque?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annulla')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Importa comunque')),
            ],
          ),
        );
        if (proceed != true || !context.mounted) return;
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final pdfsDir = Directory(p.join(docsDir.path, 'pdfs'));
    await pdfsDir.create(recursive: true);
    final destPath = p.join(pdfsDir.path, '${const Uuid().v4()}.pdf');
    await File(picked.path!).copy(destPath);

    int totalPages = 0;
    try {
      final doc = await PdfDocument.openFile(destPath);
      totalPages = doc.pagesCount;
      await doc.close();
    } catch (_) {}

    int? composerId;
    if (importResult?.authorName != null) {
      final composer = await ref
          .read(composerRepositoryProvider)
          .findOrCreate(importResult!.authorName!);
      composerId = composer.id;
    }

    final title =
        importResult?.title ?? p.basenameWithoutExtension(picked.name);
    final now = DateTime.now();
    // Salviamo path relativo alla docs dir (vedi SongPath). La rotta
    // assoluta cambia tra reinstall → i path assoluti salvati in DB
    // diventano invalidi.
    final relativeFilePath = await SongPath.toRelative(destPath);
    final savedSong = await ref.read(songRepositoryProvider).insert(Song(
          title: title,
          composerId: composerId,
          filePath: relativeFilePath,
          totalPages: totalPages,
          lastPage: 0,
          fileHash: fileHash,
          createdAt: now,
          updatedAt: now,
        ));

    if (importResult != null && importResult.setlistIds.isNotEmpty) {
      final setlistRepo = ref.read(setlistRepositoryProvider);
      for (final setlistId in importResult.setlistIds) {
        final count = await setlistRepo.getItemCount(setlistId);
        await setlistRepo.addItem(SetlistItem(
          setlistId: setlistId,
          songId: savedSong.id!,
          position: count,
        ));
      }
    }

    if (importResult != null && importResult.collectionIds.isNotEmpty) {
      final collectionRepo = ref.read(collectionRepositoryProvider);
      for (final collectionId in importResult.collectionIds) {
        await collectionRepo.addSong(collectionId, savedSong.id!);
      }
    }

    ref.invalidate(songsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$title" importato con successo')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore importazione: $e')),
      );
    }
  }
}

// ── Batch import ─────────────────────────────────────────────────────────────

Future<void> _importBatch(
    BuildContext context, WidgetRef ref, List<PlatformFile> files) async {
  final total = files.length;
  int done = 0;
  int failed = 0;
  int skipped = 0;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Importazione di $total PDF in corso…')),
  );

  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final pdfsDir = Directory(p.join(docsDir.path, 'pdfs'));
    await pdfsDir.create(recursive: true);

    for (final file in files) {
      if (file.path == null) {
        failed++;
        continue;
      }
      try {
        // Hash check — skip silent duplicates in batch mode
        final fileHash = await _computeHash(file.path!);
        if (fileHash != null) {
          final existing =
              await ref.read(songRepositoryProvider).getByHash(fileHash);
          if (existing != null) {
            skipped++;
            continue;
          }
        }

        final destPath =
            p.join(pdfsDir.path, '${const Uuid().v4()}.pdf');
        await File(file.path!).copy(destPath);

        int totalPages = 0;
        try {
          final doc = await PdfDocument.openFile(destPath);
          totalPages = doc.pagesCount;
          await doc.close();
        } catch (_) {}

        final title = p.basenameWithoutExtension(file.name);
        final now = DateTime.now();
        final relativeFilePath = await SongPath.toRelative(destPath);
        await ref.read(songRepositoryProvider).insert(Song(
              title: title,
              filePath: relativeFilePath,
              totalPages: totalPages,
              lastPage: 0,
              fileHash: fileHash,
              createdAt: now,
              updatedAt: now,
            ));
        done++;
      } catch (_) {
        failed++;
      }
    }
  } catch (e) {
    failed = total - done - skipped;
  }

  ref.invalidate(songsProvider);

  if (context.mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final parts = <String>[];
    if (done > 0) parts.add('$done importati');
    if (skipped > 0) parts.add('$skipped già presenti');
    if (failed > 0) parts.add('$failed falliti');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(parts.join(', '))));
  }
}

// ── Hash computation ──────────────────────────────────────────────────────────

Future<String?> _computeHash(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    return sha256.convert(bytes).toString();
  } catch (_) {
    return null;
  }
}
