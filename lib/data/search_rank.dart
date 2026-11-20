import '../models/track.dart';
import '../source/music_source.dart';

/// Huruf kecil, tanpa tanda baca dan spasi berlebih.
String normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// Judul tanpa keterangan dalam kurung, mis. "(Remastered 2011)".
String _baseTitle(String title) =>
    normalize(title.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' '));

/// Membuang lagu yang sama yang muncul dua kali (versi lain dengan judul dan
/// artis sama). Urutan relevansi dari YouTube Music dipertahankan.
List<Track> dedupeTracks(List<Track> tracks) {
  final seen = <String>{};
  return [
    for (final t in tracks)
      if (seen.add('${_baseTitle(t.title)}|${normalize(t.artist)}')) t,
  ];
}

/// Mengurutkan album: yang nama album atau artisnya memuat semua kata di
/// pencarian lebih dulu, lalu yang memuat sebagian. Selebihnya mengikuti
/// urutan YouTube Music.
List<PlaylistLink> rankAlbums(List<PlaylistLink> albums, String query) {
  final words = normalize(query).split(' ').where((w) => w.isNotEmpty).toSet();
  if (words.isEmpty) return albums;

  int score(PlaylistLink album) {
    final text = ' ${normalize('${album.name} ${album.by}')} ';
    final hits = words.where((w) => text.contains(' $w ')).length;
    if (hits == words.length) return 2;
    return hits > 0 ? 1 : 0;
  }

  final indexed = albums.indexed.toList()
    ..sort((a, b) {
      final byScore = score(b.$2).compareTo(score(a.$2));
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
  return [for (final (_, album) in indexed) album];
}
