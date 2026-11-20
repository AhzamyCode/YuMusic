import '../models/track.dart';

/// Lagu acuan untuk rekomendasi di Home: lagu yang disukai dan baru diputar,
/// satu per artis, yang terbaru dulu. Tiap acuan menjadi satu mix, sehingga
/// isi mix-nya segenre dengan lagu acuannya.
List<Track> pickSeeds(List<Track> liked, List<Track> history, {int max = 6}) {
  final seeds = <Track>[];
  final artists = <String>{};
  // Selang-seling antara riwayat dan disukai supaya dua-duanya terwakili.
  for (var i = 0; i < liked.length || i < history.length; i++) {
    for (final list in [history, liked]) {
      if (i >= list.length) continue;
      final track = list[i];
      final artist = track.artist.trim().toLowerCase();
      if (artist.isEmpty || !artists.add(artist)) continue;
      seeds.add(track);
      if (seeds.length == max) return seeds;
    }
  }
  return seeds;
}

/// Memilih lagu radio dari [candidates] (mix milik lagu acuan): buang yang
/// sudah ada di antrean, dan batasi tiap artis supaya radio tidak berubah
/// jadi satu artis saja.
List<Track> pickRadio(
  List<Track> candidates,
  Set<String> knownIds, {
  int limit = 20,
  int perArtist = 4,
}) {
  final seen = Set.of(knownIds);
  final counts = <String, int>{};
  final picked = <Track>[];
  for (final track in candidates) {
    if (!seen.add(track.id)) continue;
    final artist = track.artist.trim().toLowerCase();
    final count = counts[artist] ?? 0;
    if (count >= perArtist) continue;
    counts[artist] = count + 1;
    picked.add(track);
    if (picked.length == limit) break;
  }
  return picked;
}
