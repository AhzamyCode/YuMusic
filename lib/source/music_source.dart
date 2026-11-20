import 'dart:io';

import '../models/track.dart';

enum AudioQuality { low, medium, high }

class ResolvedStream {
  const ResolvedStream({
    required this.url,
    required this.mimeType,
    required this.bitrateKbps,
    required this.expiresAt,
  });

  final Uri url;
  final String mimeType;
  final int bitrateKbps;

  /// URL stream hanya berlaku beberapa jam.
  final DateTime expiresAt;

  /// Ekstensi file untuk disimpan offline.
  String get container => mimeType.contains('webm') ? 'webm' : 'm4a';
}

class RemotePlaylist {
  const RemotePlaylist({required this.title, required this.tracks});
  final String title;
  final List<Track> tracks;
}

/// Playlist di hasil pencarian atau rekomendasi; isinya dibuka lewat
/// [MusicSource.playlist].
class PlaylistLink {
  const PlaylistLink({
    required this.url,
    required this.name,
    required this.by,
    this.thumbnailUrl,
  });
  final String url;
  final String name;
  final String by;
  final String? thumbnailUrl;
}

/// Lagunya ada tapi tidak punya audio yang bisa diputar (dihapus, diblokir,
/// dibatasi umur). Tidak ada gunanya dicoba ulang; langsung ke lagu berikutnya.
class NoAudioException implements Exception {
  const NoAudioException(this.message);
  final String message;

  @override
  String toString() => 'Tidak ada audio: $message';
}

/// Satu-satunya pintu ke penyedia musik. UI dan player hanya kenal interface
/// ini, jadi extractor bisa diganti tanpa menyentuh bagian lain.
abstract class MusicSource {
  /// User-agent yang harus dipakai pemutar saat mengambil audio.
  String get userAgent;

  /// [songsOnly] membatasi hasil ke lagu saja.
  Future<List<Track>> search(String query, {bool songsOnly = true});

  /// URL stream untuk [quality]. Hasilnya disimpan sampai mendekati kedaluwarsa.
  Future<ResolvedStream> resolve(String trackId, AudioQuality quality);

  /// Menyiapkan URL [tracks] di latar, supaya tap pada salah satunya langsung
  /// mulai tanpa menunggu.
  void warm(List<Track> tracks, AudioQuality quality);

  /// Menyimpan audio ke `[basePath].<ekstensi>` dan mengembalikan filenya.
  /// [onProgress] menerima 0..1.
  Future<File> download(
    String trackId,
    AudioQuality quality, {
    required String basePath,
    void Function(double progress)? onProgress,
  });

  /// Lagu terkait, dipakai untuk radio saat antrean habis.
  Future<List<Track>> related(Track track);

  /// Playlist YouTube Music yang cocok dengan [query].
  Future<List<PlaylistLink>> searchPlaylists(String query);

  /// Album YouTube Music yang cocok dengan [query]; isinya dibuka dengan
  /// [playlist].
  Future<List<PlaylistLink>> searchAlbums(String query);

  /// Mengambil playlist publik dari link.
  Future<RemotePlaylist> playlist(String url);

  /// Membuang URL stream yang tersimpan (dipanggil saat URL ditolak server).
  void invalidate(String trackId);

  void dispose();
}
