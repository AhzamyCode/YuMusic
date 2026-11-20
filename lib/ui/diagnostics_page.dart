import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../data/database.dart';
import '../data/settings.dart';
import '../models/track.dart';
import '../player/audio_handler.dart';
import '../providers.dart';
import '../source/music_source.dart';

/// Menguji tiap tahap pemutaran satu per satu dan menampilkan error lengkapnya,
/// supaya masalah bisa dilacak tanpa menyambungkan HP ke komputer.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  final _log = StringBuffer();
  bool _running = false;

  void _write(String line) {
    if (!mounted) return;
    setState(() => _log.writeln(line));
  }

  Future<void> _run() async {
    setState(() {
      _log.clear();
      _running = true;
    });
    await Diagnostics(
      db: ref.read(databaseProvider),
      source: ref.read(musicSourceProvider),
      handler: ref.read(audioHandlerProvider),
      settings: ref.read(settingsProvider),
      write: _write,
    ).run();
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final text = _log.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.diagnostics),
        actions: [
          IconButton(
            tooltip: s.copy,
            icon: const Icon(Icons.copy),
            onPressed: text.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: text));
                    messenger.showSnackBar(SnackBar(content: Text(s.copied)));
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.diagnosticsHelp),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(s.runDiagnostics),
            onPressed: _running ? null : _run,
          ),
          const SizedBox(height: 16),
          SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class Diagnostics {
  Diagnostics({
    required this.db,
    required this.source,
    required this.handler,
    required this.settings,
    required this.write,
  });

  final AppDatabase db;
  final MusicSource source;
  final YuAudioHandler handler;
  final Settings settings;
  final void Function(String line) write;

  static String _describe(Object error) => switch (error) {
        PlatformException(:final code, :final message, :final details) =>
          'PlatformException($code): $message'
              '${details == null ? '' : '\n    $details'}',
        PlayerException(:final code, :final message) =>
          'PlayerException($code): $message',
        _ => '${error.runtimeType}: $error',
      };

  /// Menjalankan satu tahap; mengembalikan null bila gagal.
  Future<T?> _step<T>(
    String name,
    Future<T> Function() body,
    String Function(T value) describe,
  ) async {
    final watch = Stopwatch()..start();
    try {
      final value = await body().timeout(const Duration(seconds: 45));
      write('[OK]    $name (${watch.elapsedMilliseconds} ms)\n'
          '    ${describe(value)}');
      return value;
    } catch (e) {
      write('[GAGAL] $name (${watch.elapsedMilliseconds} ms)\n'
          '    ${_describe(e)}');
      return null;
    }
  }

  /// Meminta audio seperti yang dilakukan pemutar, lalu berhenti setelah
  /// beberapa ratus KB.
  Future<String> _fetch(Uri url, String userAgent, String range) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', url)
        ..headers['User-Agent'] = userAgent
        ..headers['Range'] = range;
      final response = await client.send(request);
      var bytes = 0;
      await for (final chunk in response.stream) {
        bytes += chunk.length;
        if (bytes > 300000) break;
      }
      final text = 'HTTP ${response.statusCode}, $bytes byte, '
          '${response.headers['content-type']}, '
          'content-range ${response.headers['content-range']}';
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(text);
      }
      return text;
    } finally {
      client.close();
    }
  }

  Future<void> run() async {
    write('Yumusic 0.1.0');
    write('${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    write('');
    if (handler.recentErrors.isNotEmpty) {
      write('Error pemutaran terakhir:');
      handler.recentErrors.forEach(write);
      write('');
    }

    await _step(
      'Database',
      () async => (await db.watchHistory().first).length,
      (n) => '$n lagu di riwayat',
    );
    await _step(
      'Jaringan',
      () => Connectivity().checkConnectivity(),
      (c) => c.map((r) => r.name).join(', '),
    );

    final results = await _step<List<Track>>(
      'Pencarian "tulus" (songsOnly=${settings.songsOnly})',
      () => source.search('tulus', songsOnly: settings.songsOnly),
      (r) => r.isEmpty
          ? '0 hasil'
          : '${r.length} hasil; pertama: ${r.first.title} · '
              '${r.first.artist} (${r.first.id}, ${r.first.durationSec}s)',
    );

    final track = results == null || results.isEmpty ? null : results.first;
    if (track == null) {
      write('\nTahap berikutnya dilewati karena pencarian tidak memberi lagu.');
    } else {
      source.invalidate(track.id);
      final stream = await _step<ResolvedStream>(
        'URL stream',
        () => source.resolve(track.id, AudioQuality.high),
        (s) => '${s.mimeType}, ${s.bitrateKbps} kbps, '
            'host ${s.url.host}, klien c=${s.url.queryParameters['c']}, '
            'berlaku sampai ${s.expiresAt.toLocal()}',
      );
      if (stream != null) {
        await _step(
          'Ambil audio dari awal (Range: bytes=0-)',
          () => _fetch(stream.url, source.userAgent, 'bytes=0-'),
          (s) => s,
        );
        await _step(
          'Ambil audio dari tengah (Range: bytes=1500000-)',
          () => _fetch(stream.url, source.userAgent, 'bytes=1500000-'),
          (s) => s,
        );
        await _step(
          'Pemutar memuat lagu',
          () async {
            final player = AudioPlayer(
              userAgent: source.userAgent,
              useProxyForRequestHeaders: false,
            );
            try {
              return await player.setAudioSource(AudioSource.uri(stream.url));
            } finally {
              await player.dispose();
            }
          },
          (d) => 'durasi $d',
        );
      }
      await _step(
        'Lagu terkait',
        () => source.related(track),
        (r) => '${r.length} lagu',
      );
    }

    write('\nSelesai.');
  }
}
