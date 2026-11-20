import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';
import 'music_source.dart';

/// Kapan URL stream kedaluwarsa, dibaca dari parameter `expire` (detik epoch).
/// Tanpa parameter itu, anggap berlaku 5 jam.
DateTime expiryOf(String url, {DateTime? now}) {
  final seconds = int.tryParse(
    RegExp(r'[?&]expire=(\d+)').firstMatch(url)?.group(1) ?? '',
  );
  return seconds != null
      ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
      : (now ?? DateTime.now()).add(const Duration(hours: 5));
}

/// YouTube melayani request biasa sekitar 33 KB/s, tapi request dengan
/// `range` di link dengan kecepatan penuh. [from] untuk melanjutkan download.
Uri withRange(Uri url, [int from = 0]) {
  final text = url.toString();
  if (from == 0 && text.contains('range=')) return url;
  final bare = text.replaceAll(RegExp(r'[?&]range=[^&]*'), '');
  return Uri.parse('$bare${bare.contains('?') ? '&' : '?'}range=$from-');
}

/// Implementasi [MusicSource] di atas NewPipeExtractor, yang jalan di sisi
/// Android (lihat `NewPipeBridge.kt`).
class NewPipeSource implements MusicSource {
  static const _channel = MethodChannel('app.yumusic/newpipe');

  /// URL dipakai ulang hanya selama masih berlaku lebih dari semenit.
  static const _freshMargin = Duration(minutes: 1);
  static const _searchTtl = Duration(minutes: 10);
  static const _downloadRetries = 3;

  final _http = http.Client();
  final _streams = <String, ResolvedStream>{};
  final _pending = <String, Future<ResolvedStream>>{};
  final _searches = <String, ({List<Track> items, DateTime at})>{};

  // Harus sama dengan USER_AGENT di NewPipeBridge.kt.
  @override
  String get userAgent =>
      'Mozilla/5.0 (Windows NT 10.0; rv:128.0) Gecko/20100101 Firefox/128.0';

  static String cleanArtist(String author) => author
      .replaceFirst(RegExp(r'\s+-\s+Topic$'), '')
      .replaceFirst(RegExp(r'VEVO$'), '')
      .trim();

  static List<Track> _tracks(Object? raw) => [
        for (final m in (raw as List).cast<Map<Object?, Object?>>())
          Track(
            id: m['id']! as String,
            title: (m['title'] as String?) ?? '',
            artist: cleanArtist((m['artist'] as String?) ?? ''),
            durationSec: ((m['duration'] as num?) ?? 0).toInt(),
            thumbnailUrl: (m['thumbnail'] as String?) ??
                'https://img.youtube.com/vi/${m['id']}/mqdefault.jpg',
          ),
      ];

  @override
  Future<List<Track>> search(String query, {bool songsOnly = true}) async {
    final key = '$songsOnly|${query.trim().toLowerCase()}';
    final cached = _searches[key];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _searchTtl) {
      return cached.items;
    }
    final raw = await _channel.invokeMethod<Object>(
      'search',
      {'query': query, 'songsOnly': songsOnly},
    );
    final items = _tracks(raw);
    _searches[key] = (items: items, at: DateTime.now());
    return items;
  }

  @override
  Future<ResolvedStream> resolve(String trackId, AudioQuality quality) {
    final key = '$trackId|${quality.name}';
    final cached = _streams[key];
    if (cached != null &&
        cached.expiresAt.difference(DateTime.now()) > _freshMargin) {
      return Future.value(cached);
    }
    // Lagu yang sedang dicari (disiapkan lebih dulu, lalu di-tap) ditunggu,
    // bukan dicari dua kali.
    return _pending[key] ??= _lookup(trackId, quality).then((stream) {
      _streams[key] = stream;
      return stream;
      // Blok, bukan `=>`: remove() mengembalikan future ini sendiri, dan
      // whenComplete akan menunggunya, yaitu menunggu dirinya sendiri.
    }).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<ResolvedStream> _lookup(String trackId, AudioQuality quality) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'resolve',
        {'id': trackId, 'quality': quality.name},
      );
      final url = raw!['url']! as String;
      return ResolvedStream(
        url: Uri.parse(url),
        mimeType: (raw['mime'] as String?) ?? 'audio/mp4',
        bitrateKbps: ((raw['bitrate'] as num?) ?? 0).toInt(),
        expiresAt: expiryOf(url),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NO_AUDIO') throw NoAudioException(e.message ?? trackId);
      rethrow;
    }
  }

  @override
  void warm(List<Track> tracks, AudioQuality quality) {
    for (final t in tracks) {
      unawaited(resolve(t.id, quality).then<void>((_) {}, onError: (_) {}));
    }
  }

  Future<http.StreamedResponse> _open(Uri url, int from) {
    final request = http.Request('GET', withRange(url, from))
      ..headers['User-Agent'] = userAgent;
    if (from > 0) request.headers['Range'] = 'bytes=$from-';
    return _http.send(request);
  }

  @override
  Future<File> download(
    String trackId,
    AudioQuality quality, {
    required String basePath,
    void Function(double progress)? onProgress,
  }) async {
    final part = File('$basePath.part');
    var stream = await resolve(trackId, quality);
    var written = 0;
    var tries = 0;
    try {
      while (true) {
        try {
          var response = await _open(stream.url, written);
          if (response.statusCode == 403) {
            // Link kedaluwarsa atau ditolak: ambil yang baru sekali.
            unawaited(response.stream.drain<void>().catchError((_) {}));
            invalidate(trackId);
            stream = await resolve(trackId, quality);
            response = await _open(stream.url, written);
          }
          if (response.statusCode != 200 && response.statusCode != 206) {
            unawaited(response.stream.drain<void>().catchError((_) {}));
            throw HttpException('HTTP ${response.statusCode}');
          }
          // 206 melanjutkan file; 200 berarti server mengirim ulang dari awal.
          final resumed = written > 0 && response.statusCode == 206;
          if (!resumed) written = 0;
          final length = response.contentLength;
          final total = length == null ? null : (resumed ? written : 0) + length;
          final sink = part.openWrite(
            mode: resumed ? FileMode.append : FileMode.write,
          );
          try {
            await for (final chunk in response.stream) {
              sink.add(chunk);
              written += chunk.length;
              if (total != null && total > 0) {
                onProgress?.call((written / total).clamp(0.0, 1.0));
              }
            }
          } finally {
            await sink.close();
          }
          if (total != null && written != total) {
            throw const HttpException('download terpotong');
          }
          break;
        } on NoAudioException {
          rethrow;
        } on Exception {
          // Koneksi putus: simpan yang sudah ada, minta sisanya.
          if (++tries > _downloadRetries) rethrow;
          await Future<void>.delayed(Duration(milliseconds: 1500 * tries));
        }
      }
      return await part.rename('$basePath.${stream.container}');
    } catch (_) {
      if (part.existsSync()) await part.delete();
      rethrow;
    }
  }

  @override
  Future<List<Track>> related(Track track) async =>
      _tracks(await _channel.invokeMethod<Object>('related', {'id': track.id}));

  @override
  Future<List<PlaylistLink>> searchPlaylists(String query) =>
      _lists('searchPlaylists', query);

  @override
  Future<List<PlaylistLink>> searchAlbums(String query) =>
      _lists('searchAlbums', query);

  Future<List<PlaylistLink>> _lists(String method, String query) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      method,
      {'query': query},
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        PlaylistLink(
          url: m['url']! as String,
          name: (m['name'] as String?) ?? '',
          by: (m['by'] as String?) ?? '',
          thumbnailUrl: m['thumbnail'] as String?,
        ),
    ];
  }

  @override
  Future<RemotePlaylist> playlist(String url) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'playlist',
      {'url': url.trim()},
    );
    return RemotePlaylist(
      title: (raw?['title'] as String?) ?? '',
      tracks: _tracks(raw?['tracks'] ?? const []),
    );
  }

  @override
  void invalidate(String trackId) =>
      _streams.removeWhere((k, _) => k.startsWith('$trackId|'));

  @override
  void dispose() => _http.close();
}
