import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/catalog.dart';
import 'data/database.dart';
import 'data/recommend.dart';
import 'data/search_rank.dart';
import 'data/settings.dart';
import 'l10n/strings.dart';
import 'models/track.dart';
import 'player/audio_handler.dart';
import 'player/downloads.dart';
import 'source/lyrics.dart';
import 'source/music_source.dart';

// Empat provider ini diisi di main() setelah inisialisasi.
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());
final musicSourceProvider =
    Provider<MusicSource>((ref) => throw UnimplementedError());
final audioHandlerProvider =
    Provider<YuAudioHandler>((ref) => throw UnimplementedError());
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => throw UnimplementedError());

// ---- Pengaturan ------------------------------------------------------------

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsStoreProvider).value;

  void set(Settings s) {
    ref.read(settingsStoreProvider).update(s);
    state = s;
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final localeProvider = Provider<Locale>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.language));
  if (lang != 'system') return Locale(lang);
  final system = PlatformDispatcher.instance.locale.languageCode;
  return Locale(system == 'id' ? 'id' : 'en');
});

final stringsProvider = Provider<S>(
  (ref) => S(ref.watch(localeProvider).languageCode == 'id'),
);

// ---- Player ----------------------------------------------------------------

final mediaItemProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
);

final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
);

final queueProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(audioHandlerProvider).queue,
);

final positionProvider = StreamProvider<Duration>((ref) {
  // Bergantung pada handler supaya AudioService pasti sudah siap.
  ref.watch(audioHandlerProvider);
  return AudioService.position;
});

final currentTrackProvider = Provider<Track?>((ref) {
  final item = ref.watch(mediaItemProvider).value;
  return item == null ? null : Track.fromMediaItem(item);
});

/// Skema warna dari cover lagu yang sedang diputar (null bila belum ada).
final coverSchemeProvider =
    FutureProvider.family<ColorScheme?, Brightness>((ref, brightness) async {
  final id = ref.watch(currentTrackProvider.select((t) => t?.id));
  final thumb = ref.read(currentTrackProvider)?.thumbnailUrl;
  if (id == null || thumb == null) return null;
  try {
    return await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(thumb),
      brightness: brightness,
    );
  } catch (_) {
    return null;
  }
});

// ---- Pencarian -------------------------------------------------------------

class SearchResults {
  const SearchResults({required this.songs, required this.albums});
  final List<Track> songs;
  final List<PlaylistLink> albums;

  bool get isEmpty => songs.isEmpty && albums.isEmpty;
}

/// Lagu dan album dicari bersamaan. Album yang gagal dimuat tidak
/// menggagalkan pencarian; lagu tetap tampil.
final searchProvider =
    FutureProvider.autoDispose.family<SearchResults, String>((ref, query) async {
  final songsOnly = ref.watch(settingsProvider.select((s) => s.songsOnly));
  final source = ref.watch(musicSourceProvider);
  final albumsFuture =
      source.searchAlbums(query).catchError((_) => <PlaylistLink>[]);
  final songs = dedupeTracks(await source.search(query, songsOnly: songsOnly));
  final albums = rankAlbums(await albumsFuture, query);
  // Hasil teratas disiapkan selagi pengguna melihat daftar, supaya tap pada
  // salah satunya langsung mulai.
  unawaited(
    currentQuality(ref.read(settingsProvider))
        .then((quality) => source.warm(songs.take(3).toList(), quality)),
  );
  return SearchResults(songs: songs, albums: albums);
});

// ---- Library ---------------------------------------------------------------

final playlistsProvider = StreamProvider<List<PlaylistInfo>>(
  (ref) => ref.watch(databaseProvider).watchPlaylists(),
);

final playlistProvider = StreamProvider.autoDispose.family<PlaylistRow?, int>(
  (ref, id) => ref.watch(databaseProvider).watchPlaylist(id),
);

final playlistTracksProvider =
    StreamProvider.autoDispose.family<List<Track>, int>(
  (ref, id) => ref.watch(databaseProvider).watchPlaylistTracks(id),
);

final likedProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(databaseProvider).watchLiked(),
);

final likedIdsProvider = Provider<Set<String>>(
  (ref) =>
      ref.watch(likedProvider).value?.map((t) => t.id).toSet() ?? const {},
);

final historyProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(databaseProvider).watchHistory(),
);

final downloadsProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(databaseProvider).watchDownloads(),
);

final downloadedIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).watchDownloadedIds(),
);

final downloadManagerProvider =
    NotifierProvider<DownloadManager, Map<String, double>>(DownloadManager.new);

// ---- Lirik -----------------------------------------------------------------

final lyricsProvider = FutureProvider.autoDispose.family<Lyrics?, Track>(
  (ref, track) => fetchLyrics(track),
);

// ---- Home ------------------------------------------------------------------

/// Lagu acuan rekomendasi. Dibaca sekali (bukan diikuti terus), supaya Home
/// tidak mengambil ulang dari internet setiap satu lagu selesai diputar.
final seedsProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  return pickSeeds(await db.watchLiked().first, await db.watchHistory().first);
});

/// Playlist YouTube Music untuk artis yang sering didengar; sebelum ada
/// riwayat, playlist populer.
final recommendedPlaylistsProvider =
    FutureProvider<List<PlaylistLink>>((ref) async {
  final source = ref.watch(musicSourceProvider);
  final seeds = await ref.watch(seedsProvider.future);
  final queries = seeds.isEmpty
      ? starterPlaylistQueries
      : seeds.take(3).map((t) => t.artist).toList();
  final results = await Future.wait([
    for (final q in queries)
      source.searchPlaylists(q).catchError((_) => <PlaylistLink>[]),
  ]);
  // Selang-seling antar artis, tanpa playlist ganda.
  final seen = <String>{};
  final merged = <PlaylistLink>[];
  for (var i = 0; merged.length < 12; i++) {
    var any = false;
    for (final list in results) {
      if (i >= list.length) continue;
      any = true;
      if (seen.add(list[i].url)) merged.add(list[i]);
    }
    if (!any) break;
  }
  return merged;
});

final genrePlaylistsProvider =
    FutureProvider.autoDispose.family<List<PlaylistLink>, String>(
  (ref, query) => ref.watch(musicSourceProvider).searchPlaylists(query),
);

final genreSongsProvider = FutureProvider.autoDispose
    .family<List<Track>, String>(
  (ref, query) => ref.watch(musicSourceProvider).search(query),
);

// ---- Statistik ---------------------------------------------------------------

enum StatsPeriod { week, month, all }

DateTime? periodStart(StatsPeriod period, [DateTime? now]) {
  final today = now ?? DateTime.now();
  return switch (period) {
    StatsPeriod.week => today.subtract(const Duration(days: 7)),
    StatsPeriod.month => today.subtract(const Duration(days: 30)),
    StatsPeriod.all => null,
  };
}

final topTracksProvider =
    StreamProvider.autoDispose.family<List<TrackStat>, StatsPeriod>(
  (ref, period) => ref
      .watch(databaseProvider)
      .watchTopTracks(since: periodStart(period)),
);

final topArtistsProvider =
    StreamProvider.autoDispose.family<List<ArtistStat>, StatsPeriod>(
  (ref, period) => ref
      .watch(databaseProvider)
      .watchTopArtists(since: periodStart(period)),
);

final summaryProvider =
    StreamProvider.autoDispose.family<ListenSummary, StatsPeriod>(
  (ref, period) =>
      ref.watch(databaseProvider).watchSummary(since: periodStart(period)),
);
