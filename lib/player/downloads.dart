import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../providers.dart';

class WifiRequiredException implements Exception {
  const WifiRequiredException();
}

/// Download yang sedang berjalan: id lagu -> progres 0..1.
class DownloadManager extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void _progress(String id, double? value) {
    final next = Map.of(state);
    if (value == null) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    state = next;
  }

  /// Menyimpan audio ke penyimpanan app. Melempar [WifiRequiredException]
  /// bila pengaturan "hanya Wi-Fi" aktif dan sedang tidak di Wi-Fi.
  Future<void> download(Track track) async {
    if (state.containsKey(track.id)) return;
    final settings = ref.read(settingsProvider);
    final db = ref.read(databaseProvider);
    final source = ref.read(musicSourceProvider);

    if (settings.downloadWifiOnly) {
      final c = await Connectivity().checkConnectivity();
      if (!c.contains(ConnectivityResult.wifi) &&
          !c.contains(ConnectivityResult.ethernet)) {
        throw const WifiRequiredException();
      }
    }

    _progress(track.id, 0);
    try {
      final quality = settings.qualityWifi;
      final dir = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'downloads'),
      );
      await dir.create(recursive: true);
      final file = await source.download(
        track.id,
        quality,
        basePath: p.join(dir.path, track.id),
        onProgress: (value) => _progress(track.id, value),
      );
      await db.saveDownload(
        track,
        path: file.path,
        sizeMb: await file.length() / (1024 * 1024),
        quality: quality.name,
      );
    } finally {
      _progress(track.id, null);
    }
  }

  Future<void> remove(String trackId) async {
    final db = ref.read(databaseProvider);
    final row = await db.downloadFor(trackId);
    if (row == null) return;
    final file = File(row.path);
    if (file.existsSync()) await file.delete();
    await db.removeDownload(trackId);
  }
}
