import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration time;
  final String text;
}

class Lyrics {
  const Lyrics({this.synced = const [], this.plain});

  /// Baris bertanda waktu; kosong bila hanya ada lirik biasa.
  final List<LyricLine> synced;
  final String? plain;

  bool get isSynced => synced.isNotEmpty;
}

final _lrcLine = RegExp(r'^\[(\d+):(\d+)(?:[.:](\d+))?\]\s?(.*)$');

List<LyricLine> parseLrc(String lrc) {
  final out = <LyricLine>[];
  for (final raw in const LineSplitter().convert(lrc)) {
    final m = _lrcLine.firstMatch(raw.trim());
    if (m == null) continue;
    final frac = m.group(3) ?? '0';
    final ms = (int.parse(frac) * 1000 / _pow10(frac.length)).round();
    out.add(
      LyricLine(
        Duration(
          minutes: int.parse(m.group(1)!),
          seconds: int.parse(m.group(2)!),
          milliseconds: ms,
        ),
        m.group(4)!.trim(),
      ),
    );
  }
  return out;
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Judul video sering berisi embel-embel; buang supaya cocok dengan LRCLIB.
String cleanTitle(String title, String artist) {
  var t = title
      .replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' ')
      .replaceAll(
        RegExp(
          r'\b(official|music|lyrics?|video|audio|mv|hd|4k)\b',
          caseSensitive: false,
        ),
        ' ',
      );
  if (artist.isNotEmpty) {
    final prefix = RegExp(
      '^\\s*${RegExp.escape(artist)}\\s*[-–—:|]\\s*',
      caseSensitive: false,
    );
    t = t.replaceFirst(prefix, '');
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[-–—|\s]+$'), '').trim();
}

/// Mengambil lirik dari LRCLIB. Mengembalikan null bila tidak ditemukan.
Future<Lyrics?> fetchLyrics(Track track, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final q = '${cleanTitle(track.title, track.artist)} ${track.artist}'.trim();
    final res = await c.get(
      Uri.https('lrclib.net', '/api/search', {'q': q}),
      headers: {'User-Agent': 'Yumusic (open source music player)'},
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;

    // Pilih yang durasinya paling dekat, utamakan yang punya lirik sinkron.
    int score(Map<String, dynamic> e) {
      final d = (e['duration'] as num?)?.round() ?? 0;
      final diff = track.durationSec > 0 ? (d - track.durationSec).abs() : 0;
      return diff * 2 + (e['syncedLyrics'] == null ? 5 : 0);
    }

    list.sort((a, b) => score(a).compareTo(score(b)));
    final best = list.first;
    final d = (best['duration'] as num?)?.round() ?? 0;
    if (track.durationSec > 0 && (d - track.durationSec).abs() > 15) {
      return null;
    }
    final synced = best['syncedLyrics'] as String?;
    final plain = best['plainLyrics'] as String?;
    if (synced == null && (plain == null || plain.isEmpty)) return null;
    return Lyrics(
      synced: synced == null ? const [] : parseLrc(synced),
      plain: plain,
    );
  } finally {
    if (client == null) c.close();
  }
}
