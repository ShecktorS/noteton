import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/exceptions/backup_exceptions.dart';
import '../../domain/models/import_report.dart';
import '../../domain/models/tag.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';
import 'auto_update_screen.dart';
import 'diagnostic_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isImporting = false;
  String _appVersion = '';

  // Contatore tap nascosto per aprire il pannello diagnostico (7 tap <3s).
  int _versionTapCount = 0;
  DateTime? _versionFirstTap;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _exportBackup() async {
    if (!mounted) return;

    // Ask the user how they want to save the backup
    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Salva sul dispositivo'),
              subtitle: const Text('Scegli dove salvare il file .ntb'),
              onTap: () => Navigator.pop(ctx, _ExportChoice.save),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Condividi…'),
              subtitle: const Text('Invia via email, Drive, WhatsApp…'),
              onTap: () => Navigator.pop(ctx, _ExportChoice.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final backup = ref.read(backupRepositoryProvider);
    try {
      final tempPath = await backup.createBackupFile();
      final fileName = tempPath.split('/').last;

      if (choice == _ExportChoice.save) {
        // On Android/iOS, file_picker.saveFile() requires bytes to perform the write itself
        final bytes = await File(tempPath).readAsBytes();
        final destPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Salva backup Noteton',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['ntb'],
          bytes: bytes,
        );
        if (destPath == null) return; // user cancelled
        // On desktop, saveFile returns the path but doesn't write — copy fallback
        final saved = File(destPath);
        if (!await saved.exists() || (await saved.length()) == 0) {
          await File(tempPath).copy(destPath);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup salvato sul dispositivo')),
          );
        }
      } else {
        await Share.shareXFiles(
          [XFile(tempPath, mimeType: 'application/octet-stream')],
          subject: 'Noteton Backup',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore backup: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    // NB: usiamo FileType.any invece di custom+allowedExtensions['ntb']
    // perché `.ntb` non ha un MIME type registrato su Android e il picker
    // nativo può chiudersi subito senza mostrare il file. Validiamo il
    // suffisso lato Dart dopo la selezione.
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile aprire il selettore file: $e')),
        );
      }
      return;
    }

    if (result == null || result.files.single.path == null) {
      // Selezione annullata dall'utente — nessun feedback necessario
      return;
    }
    if (!mounted) return;

    final selectedPath = result.files.single.path!;
    if (!selectedPath.toLowerCase().endsWith('.ntb')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seleziona un file con estensione .ntb '
                '(backup Noteton)')),
      );
      return;
    }

    // Dialog di scelta modalità: Unisci vs Sostituisci tutto
    final choice = await showDialog<_ImportMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modalità ripristino'),
        content: const Text(
          'Come vuoi ripristinare il backup?\n\n'
          '• Unisci: aggiunge i brani del backup alla libreria attuale, '
          'saltando i duplicati (stesso PDF).\n\n'
          '• Sostituisci tutto: cancella l\'intera libreria attuale '
          '(brani, setlist, raccolte, tag, annotazioni) e importa il backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImportMode.merge),
            child: const Text('Unisci'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImportMode.replace),
            child: const Text(
              'Sostituisci tutto',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (!mounted) return;

    // Seconda conferma per la modalità distruttiva
    if (choice == _ImportMode.replace) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancellare tutta la libreria?'),
          content: const Text(
            'Questa azione è irreversibile. Tutti i brani, setlist, '
            'raccolte, tag e annotazioni attuali verranno sostituiti dal '
            'contenuto del backup. Vuoi continuare?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Cancella e ripristina',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      if (!mounted) return;
    }

    setState(() => _isImporting = true);

    final backup = ref.read(backupRepositoryProvider);
    try {
      final report = await backup.importBackup(
        selectedPath,
        wipeBeforeImport: choice == _ImportMode.replace,
      );
      // Invalida tutti i provider affinché UI si aggiorni subito
      ref.invalidate(songsProvider);
      ref.invalidate(setlistsProvider);
      ref.invalidate(collectionsProvider);
      ref.invalidate(tagsProvider);
      if (mounted) {
        _showImportReport(report);
      }
    } on BackupException catch (e) {
      if (mounted) _showImportError(e.userMessage, technicalDetail: e.technicalDetail);
    } catch (e) {
      if (mounted) {
        _showImportError(
            'Ripristino non riuscito per un errore imprevisto.',
            technicalDetail: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showImportReport(ImportReport report) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(report.hasWarnings
            ? 'Ripristino completato con avvisi'
            : 'Ripristino completato'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(report.shortSummary),
              const SizedBox(height: 12),
              Text(
                report.fullText,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report.fullText));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Dettagli copiati')),
              );
            },
            child: const Text('Copia dettagli'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImportError(String userMessage, {String? technicalDetail}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristino non riuscito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userMessage),
            if (technicalDetail != null && technicalDetail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text('Dettagli tecnici'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        technicalDetail,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  void _onVersionTapped() {
    final now = DateTime.now();
    if (_versionFirstTap == null ||
        now.difference(_versionFirstTap!) > const Duration(seconds: 3)) {
      _versionFirstTap = now;
      _versionTapCount = 1;
      return;
    }
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _versionFirstTap = null;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const DiagnosticScreen(),
      ));
    }
  }

  void _showMigrationGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrazione da MobileSheets'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MigrationStep(
                number: '1',
                title: 'Esporta il backup .msb da MobileSheets',
                body:
                    'Apri MobileSheets → Menu → Backup/Ripristino → '
                    '"Crea backup". Il file generato ha estensione .msb '
                    '(non è uno ZIP — è un formato proprietario).',
              ),
              SizedBox(height: 16),
              _MigrationStep(
                number: '2',
                title: 'Converti su PC con msb2ntb',
                body:
                    'Copia il file .msb sul tuo PC. '
                    'Scarica msb2ntb (disponibile su GitHub) ed eseguilo: '
                    'trascina il file .msb sull\'icona di msb2ntb.exe '
                    'oppure avvialo con doppio clic e inserisci il percorso '
                    'quando richiesto. Viene creato un file .ntb con gli '
                    'stessi PDF, titoli e autori.',
              ),
              SizedBox(height: 16),
              _MigrationStep(
                number: '3',
                title: 'Copia il .ntb sul telefono',
                body:
                    'Trasferisci il file .ntb sul dispositivo Android '
                    'tramite USB, Google Drive, Telegram o qualsiasi altro '
                    'metodo. Tienilo in una cartella facilmente raggiungibile '
                    '(es. Download).',
              ),
              SizedBox(height: 16),
              _MigrationStep(
                number: '4',
                title: 'Ripristina in Noteton',
                body:
                    'Apri Noteton → Impostazioni → Ripristina backup → '
                    'seleziona il file .ntb. Scegli "Unisci" per aggiungere '
                    'i brani alla libreria esistente, oppure "Sostituisci '
                    'tutto" se vuoi partire da zero. I duplicati vengono '
                    'rilevati automaticamente tramite hash SHA-256.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: Stack(
        children: [
          ListView(
            children: [
              const _SectionHeader('Aspetto'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Chiaro'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Sistema'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Scuro'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) =>
                      ref.read(themeModeProvider.notifier).setMode(selection.first),
                ),
              ),
              const Divider(),
              const _SectionHeader('Bluetooth'),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Pedale page-turner'),
                subtitle: const Text('Nessun dispositivo connesso'),
                onTap: () {
                  // TODO: implement Bluetooth settings (Fase 3)
                },
              ),
              const Divider(),
              const _SectionHeader('Tag'),
              _TagsSection(),
              const Divider(),
              const _SectionHeader('Dati'),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup libreria'),
                subtitle: const Text('Esporta brani, setlist e raccolte in un file .ntb'),
                onTap: _isImporting ? null : _exportBackup,
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Ripristina backup'),
                subtitle: const Text('Importa da un file .ntb'),
                onTap: _isImporting ? null : _importBackup,
              ),
              const Divider(),
              // ── Aggiornamenti ─────────────────────────────────────────────
              const _SectionHeader('Aggiornamenti'),
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('Aggiornamento automatico'),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final enabled = ref.watch(autoUpdateEnabledProvider);
                    return Text(enabled
                        ? 'Notifica al lancio quando esce una nuova versione'
                        : 'Disattivato — controllo solo manuale');
                  },
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AutoUpdateScreen()),
                ),
              ),
              const Divider(),
              // ── Info ──────────────────────────────────────────────────────
              const _SectionHeader('Info'),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: const Text('Migrazione da MobileSheets'),
                subtitle: const Text('Come importare i tuoi PDF da MobileSheets'),
                onTap: () => _showMigrationGuide(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Versione'),
                subtitle: Text(
                    'Noteton${_appVersion.isNotEmpty ? ' $_appVersion' : ''}'),
                onTap: _onVersionTapped,
              ),
              const ListTile(
                leading: Icon(Icons.balance),
                title: Text('Licenza'),
                subtitle: Text('MIT / GPL · Open Source'),
              ),
            ],
          ),
          if (_isImporting)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

enum _ExportChoice { save, share }

enum _ImportMode { merge, replace }

// ── Migration guide step widget ───────────────────────────────────────────────

class _MigrationStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _MigrationStep({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(body, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tags section ──────────────────────────────────────────────────────────────

class _TagsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TagsSection> createState() => _TagsSectionState();
}

class _TagsSectionState extends ConsumerState<_TagsSection> {
  static const _palette = [
    '#E53935', '#F4511E', '#EF9E00', '#0B8043', '#039BE5',
    '#3F51B5', '#8E24AA', '#D81B60', '#546E7A', '#795548',
  ];

  Future<void> _createTag() async {
    final nameCtrl = TextEditingController();
    String selectedColor = _palette.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuovo tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Colore', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _palette.map((hex) {
                  final color =
                      Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final selected = selectedColor == hex;
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColor = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crea'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    await ref.read(tagRepositoryProvider).insert(
          Tag(name: nameCtrl.text.trim(), color: selectedColor),
        );
    ref.invalidate(tagsProvider);
  }

  Future<void> _deleteTag(Tag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Elimina "${tag.name}"?'),
        content: const Text(
            'Il tag sarà rimosso da tutti i brani. Questa azione non è reversibile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tagRepositoryProvider).delete(tag.id!);
    ref.invalidate(tagsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    return tagsAsync.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator()),
      error: (e, _) => Text('Errore: $e'),
      data: (tags) => Column(
        children: [
          ...tags.map((tag) {
            final color =
                Color(int.parse(tag.color.replaceFirst('#', '0xFF')));
            return ListTile(
              leading: Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              title: Text(tag.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _deleteTag(tag),
              ),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Nuovo tag'),
            onTap: _createTag,
          ),
        ],
      ),
    );
  }
}
