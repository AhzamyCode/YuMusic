import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../providers.dart';
import '../source/music_source.dart';
import 'diagnostics_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final data = await ref.read(databaseProvider).exportData();
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final saved = await FilePicker.saveFile(
      fileName: 'yumusic-backup-$date.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupSaved)));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.firstOrNull?.path;
    if (path == null) return;
    try {
      final json = jsonDecode(await File(path).readAsString());
      await db.importData(json as Map<String, dynamic>);
      messenger.showSnackBar(SnackBar(content: Text(s.backupRestored)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget header(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            label,
            style: text.titleSmall?.copyWith(color: scheme.primary),
          ),
        );

    String qualityLabel(AudioQuality q) => switch (q) {
          AudioQuality.low => s.qualityLow,
          AudioQuality.medium => s.qualityMedium,
          AudioQuality.high => s.qualityHigh,
        };

    Widget choice<T>({
      required String title,
      required T value,
      required Map<T, String> options,
      required ValueChanged<T> onChanged,
    }) =>
        ListTile(
          title: Text(title),
          subtitle: Text(options[value] ?? ''),
          onTap: () async {
            final picked = await showDialog<T>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: Text(title),
                children: [
                  for (final e in options.entries)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, e.key),
                      child: Row(
                        children: [
                          Icon(
                            e.key == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: e.key == value ? scheme.primary : null,
                          ),
                          const SizedBox(width: 16),
                          Text(e.value),
                        ],
                      ),
                    ),
                ],
              ),
            );
            if (picked != null) onChanged(picked);
          },
        );

    final qualities = {for (final q in AudioQuality.values) q: qualityLabel(q)};

    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(s.settings, style: text.headlineSmall),
          ),
          header(s.appearance),
          choice<ThemeMode>(
            title: s.theme,
            value: settings.themeMode,
            options: {
              ThemeMode.system: s.themeSystem,
              ThemeMode.light: s.themeLight,
              ThemeMode.dark: s.themeDark,
            },
            onChanged: (v) => notifier.set(settings.copyWith(themeMode: v)),
          ),
          SwitchListTile(
            title: Text(s.dynamicColor),
            value: settings.dynamicColor,
            onChanged: (v) => notifier.set(settings.copyWith(dynamicColor: v)),
          ),
          choice<String>(
            title: s.language,
            value: settings.language,
            options: {
              'system': s.themeSystem,
              'id': 'Bahasa Indonesia',
              'en': 'English',
            },
            onChanged: (v) => notifier.set(settings.copyWith(language: v)),
          ),
          header(s.playback),
          choice<AudioQuality>(
            title: s.qualityWifi,
            value: settings.qualityWifi,
            options: qualities,
            onChanged: (v) => notifier.set(settings.copyWith(qualityWifi: v)),
          ),
          choice<AudioQuality>(
            title: s.qualityMobile,
            value: settings.qualityMobile,
            options: qualities,
            onChanged: (v) => notifier.set(settings.copyWith(qualityMobile: v)),
          ),
          SwitchListTile(
            title: Text(s.autoRadio),
            subtitle: Text(s.autoRadioDesc),
            value: settings.autoRadio,
            onChanged: (v) => notifier.set(settings.copyWith(autoRadio: v)),
          ),
          SwitchListTile(
            title: Text(s.songsOnly),
            subtitle: Text(s.songsOnlyDesc),
            value: settings.songsOnly,
            onChanged: (v) => notifier.set(settings.copyWith(songsOnly: v)),
          ),
          SwitchListTile(
            title: Text(s.wifiOnly),
            value: settings.downloadWifiOnly,
            onChanged: (v) =>
                notifier.set(settings.copyWith(downloadWifiOnly: v)),
          ),
          ListTile(
            title: Text(s.battery),
            subtitle: Text(s.batteryDesc),
            onTap: () => _showBatteryGuide(context, s),
          ),
          ListTile(
            title: Text(s.diagnostics),
            subtitle: Text(s.diagnosticsDesc),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage()),
            ),
          ),
          header(s.data),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(s.exportBackup),
            subtitle: Text(s.exportDesc),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(s.importBackup),
            subtitle: Text(s.importDesc),
            onTap: () => _import(context, ref),
          ),
          header(s.about),
          ListTile(
            title: const Text('Yumusic 0.1.0'),
            subtitle: Text(s.aboutDesc),
          ),
        ],
      ),
    );
  }

  void _showBatteryGuide(BuildContext context, S s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.battery),
        content: SingleChildScrollView(child: Text(s.batteryGuide)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.ok)),
        ],
      ),
    );
  }
}
