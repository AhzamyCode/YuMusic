import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/track.dart';

part 'database.g.dart';

@DataClassName('TrackRow')
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  IntColumn get durationSec => integer()();
  TextColumn get thumbnailUrl => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('PlaylistTrackRow')
class PlaylistTracks extends Table {
  IntColumn get playlistId => integer()();
  TextColumn get trackId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

@DataClassName('LikedRow')
class Liked extends Table {
  TextColumn get trackId => text()();
  DateTimeColumn get likedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {trackId};
}

@DataClassName('HistoryRow')
class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  DateTimeColumn get playedAt => dateTime()();
}

/// Satu baris per putaran (tidak digabung seperti [History]), untuk
/// menghitung lagu yang paling sering diputar.
@DataClassName('PlayRow')
class Plays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  DateTimeColumn get playedAt => dateTime()();
}

@DataClassName('DownloadRow')
class Downloads extends Table {
  TextColumn get trackId => text()();
  TextColumn get path => text()();
  RealColumn get sizeMb => real()();
  TextColumn get quality => text()();

  @override
  Set<Column> get primaryKey => {trackId};
}

class PlaylistInfo {
  const PlaylistInfo({
    required this.id,
    required this.name,
    required this.count,
    this.coverUrl,
  });
  final int id;
  final String name;
  final int count;
  final String? coverUrl;
}

const historyLimit = 100;

class TrackStat {
  const TrackStat(this.track, this.plays);
  final Track track;
  final int plays;
}

class ArtistStat {
  const ArtistStat(this.name, this.plays, this.coverUrl);
  final String name;
  final int plays;
  final String? coverUrl;
}

class ListenSummary {
  const ListenSummary({
    required this.plays,
    required this.songs,
    required this.artists,
    required this.minutes,
  });
  final int plays;
  final int songs;
  final int artists;

  /// Perkiraan: jumlah durasi lagu yang diputar.
  final int minutes;
}

@DriftDatabase(
  tables: [
    Tracks,
    Playlists,
    PlaylistTracks,
    Liked,
    History,
    Downloads,
    Plays,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'yumusic'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(plays);
            // Riwayat yang sudah ada dihitung sebagai satu putaran per lagu.
            await customStatement(
              'INSERT INTO plays (track_id, played_at) '
              'SELECT track_id, played_at FROM history',
            );
          }
        },
      );

  // ---- Statistik ---------------------------------------------------------

  Future<void> recordPlay(String trackId, {DateTime? at}) => into(plays).insert(
        PlaysCompanion.insert(trackId: trackId, playedAt: at ?? DateTime.now()),
      );

  /// Lagu paling sering diputar sejak [since] (semua waktu bila null).
  Stream<List<TrackStat>> watchTopTracks({DateTime? since, int limit = 50}) =>
      customSelect(
        'SELECT t.*, COUNT(*) AS c, MAX(p.played_at) AS last '
        'FROM plays p JOIN tracks t ON t.id = p.track_id '
        'WHERE p.played_at >= ? '
        'GROUP BY t.id ORDER BY c DESC, last DESC LIMIT ?',
        variables: [
          Variable.withDateTime(since ?? DateTime(1970)),
          Variable.withInt(limit),
        ],
        readsFrom: {plays, tracks},
      ).watch().map(
            (rows) => [
              for (final r in rows)
                TrackStat(_toTrack(tracks.map(r.data)), r.read<int>('c')),
            ],
          );

  Stream<List<ArtistStat>> watchTopArtists({DateTime? since, int limit = 5}) =>
      customSelect(
        'SELECT t.artist AS artist, COUNT(*) AS c, '
        'MAX(t.thumbnail_url) AS cover '
        'FROM plays p JOIN tracks t ON t.id = p.track_id '
        "WHERE p.played_at >= ? AND t.artist != '' "
        'GROUP BY t.artist ORDER BY c DESC LIMIT ?',
        variables: [
          Variable.withDateTime(since ?? DateTime(1970)),
          Variable.withInt(limit),
        ],
        readsFrom: {plays, tracks},
      ).watch().map(
            (rows) => [
              for (final r in rows)
                ArtistStat(
                  r.read<String>('artist'),
                  r.read<int>('c'),
                  r.readNullable<String>('cover'),
                ),
            ],
          );

  Stream<ListenSummary> watchSummary({DateTime? since}) => customSelect(
        'SELECT COUNT(*) AS plays, COUNT(DISTINCT p.track_id) AS songs, '
        'COUNT(DISTINCT t.artist) AS artists, '
        'COALESCE(SUM(t.duration_sec), 0) AS secs '
        'FROM plays p JOIN tracks t ON t.id = p.track_id '
        'WHERE p.played_at >= ?',
        variables: [Variable.withDateTime(since ?? DateTime(1970))],
        readsFrom: {plays, tracks},
      ).watchSingle().map(
            (r) => ListenSummary(
              plays: r.read<int>('plays'),
              songs: r.read<int>('songs'),
              artists: r.read<int>('artists'),
              minutes: r.read<int>('secs') ~/ 60,
            ),
          );

  // ---- Track -------------------------------------------------------------

  Track _toTrack(TrackRow r) => Track(
        id: r.id,
        title: r.title,
        artist: r.artist,
        durationSec: r.durationSec,
        thumbnailUrl: r.thumbnailUrl,
      );

  Future<void> upsertTrack(Track t) => into(tracks).insertOnConflictUpdate(
        TracksCompanion.insert(
          id: t.id,
          title: t.title,
          artist: t.artist,
          durationSec: t.durationSec,
          thumbnailUrl: t.thumbnailUrl,
        ),
      );

  List<Track> _tracksOf(List<TypedResult> rows) =>
      rows.map((r) => _toTrack(r.readTable(tracks))).toList();

  // ---- Playlist ----------------------------------------------------------

  Stream<List<PlaylistInfo>> watchPlaylists() {
    return customSelect(
      'SELECT p.id, p.name, '
      '(SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS c, '
      '(SELECT t.thumbnail_url FROM playlist_tracks pt '
      ' JOIN tracks t ON t.id = pt.track_id '
      ' WHERE pt.playlist_id = p.id ORDER BY pt.position LIMIT 1) AS cover '
      'FROM playlists p ORDER BY p.created_at DESC, p.id DESC',
      readsFrom: {playlists, playlistTracks, tracks},
    ).watch().map(
          (rows) => rows
              .map(
                (r) => PlaylistInfo(
                  id: r.read<int>('id'),
                  name: r.read<String>('name'),
                  count: r.read<int>('c'),
                  coverUrl: r.readNullable<String>('cover'),
                ),
              )
              .toList(),
        );
  }

  Stream<PlaylistRow?> watchPlaylist(int id) =>
      (select(playlists)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<int> createPlaylist(String name, {DateTime? createdAt}) =>
      into(playlists).insert(
        PlaylistsCompanion.insert(
          name: name,
          createdAt: createdAt ?? DateTime.now(),
        ),
      );

  Future<void> renamePlaylist(int id, String name) =>
      (update(playlists)..where((p) => p.id.equals(id)))
          .write(PlaylistsCompanion(name: Value(name)));

  Future<void> deletePlaylist(int id) => transaction(() async {
        await (delete(playlistTracks)..where((p) => p.playlistId.equals(id)))
            .go();
        await (delete(playlists)..where((p) => p.id.equals(id))).go();
      });

  JoinedSelectStatement<HasResultSet, dynamic> _playlistTracksQuery(int id) =>
      select(playlistTracks).join([
        innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
      ])
        ..where(playlistTracks.playlistId.equals(id))
        ..orderBy([OrderingTerm.asc(playlistTracks.position)]);

  Stream<List<Track>> watchPlaylistTracks(int id) =>
      _playlistTracksQuery(id).watch().map(_tracksOf);

  Future<List<Track>> playlistTracksOnce(int id) =>
      _playlistTracksQuery(id).get().then(_tracksOf);

  /// Menambah lagu ke akhir playlist. Lagu yang sudah ada dilewati.
  /// Mengembalikan jumlah lagu yang benar-benar ditambahkan.
  Future<int> addToPlaylist(int playlistId, List<Track> items) =>
      transaction(() async {
        final maxExpr = playlistTracks.position.max();
        final row = await (selectOnly(playlistTracks)
              ..addColumns([maxExpr])
              ..where(playlistTracks.playlistId.equals(playlistId)))
            .getSingle();
        var next = (row.read(maxExpr) ?? -1) + 1;
        final present = {
          for (final r in await (select(playlistTracks)
                ..where((p) => p.playlistId.equals(playlistId)))
              .get())
            r.trackId,
        };
        var added = 0;
        for (final t in items) {
          if (!present.add(t.id)) continue;
          await upsertTrack(t);
          await into(playlistTracks).insert(
            PlaylistTracksCompanion.insert(
              playlistId: playlistId,
              trackId: t.id,
              position: next++,
            ),
          );
          added++;
        }
        return added;
      });

  Future<void> removeFromPlaylist(int playlistId, String trackId) =>
      (delete(playlistTracks)
            ..where(
              (p) =>
                  p.playlistId.equals(playlistId) & p.trackId.equals(trackId),
            ))
          .go();

  // ---- Disukai -----------------------------------------------------------

  Stream<List<Track>> watchLiked() => (select(liked).join([
        innerJoin(tracks, tracks.id.equalsExp(liked.trackId)),
      ])
            ..orderBy([OrderingTerm.desc(liked.likedAt)]))
          .watch()
          .map(_tracksOf);

  Stream<bool> watchIsLiked(String trackId) =>
      (select(liked)..where((l) => l.trackId.equals(trackId)))
          .watchSingleOrNull()
          .map((r) => r != null);

  Future<void> setLiked(Track t, bool value, {DateTime? at}) async {
    if (value) {
      await upsertTrack(t);
      await into(liked).insertOnConflictUpdate(
        LikedCompanion.insert(trackId: t.id, likedAt: at ?? DateTime.now()),
      );
    } else {
      await (delete(liked)..where((l) => l.trackId.equals(t.id))).go();
    }
  }

  // ---- Riwayat -----------------------------------------------------------

  Stream<List<Track>> watchHistory() => (select(history).join([
        innerJoin(tracks, tracks.id.equalsExp(history.trackId)),
      ])
            ..orderBy([
              OrderingTerm.desc(history.playedAt),
              OrderingTerm.desc(history.id),
            ]))
          .watch()
          .map(_tracksOf);

  /// Mencatat lagu ke riwayat; hanya [historyLimit] entri terakhir disimpan
  /// dan satu lagu hanya muncul sekali (yang terbaru).
  Future<void> addHistory(Track t, {DateTime? at}) => transaction(() async {
        await upsertTrack(t);
        await (delete(history)..where((h) => h.trackId.equals(t.id))).go();
        await into(history).insert(
          HistoryCompanion.insert(
            trackId: t.id,
            playedAt: at ?? DateTime.now(),
          ),
        );
        await customUpdate(
          'DELETE FROM history WHERE id NOT IN '
          '(SELECT id FROM history ORDER BY played_at DESC, id DESC LIMIT ?)',
          variables: [Variable.withInt(historyLimit)],
          updates: {history},
          updateKind: UpdateKind.delete,
        );
      });

  Future<void> clearHistory() => delete(history).go();

  // ---- Download ----------------------------------------------------------

  Stream<List<Track>> watchDownloads() => (select(downloads).join([
        innerJoin(tracks, tracks.id.equalsExp(downloads.trackId)),
      ])
            ..orderBy([OrderingTerm.asc(tracks.title)]))
          .watch()
          .map(_tracksOf);

  Stream<Set<String>> watchDownloadedIds() =>
      select(downloads).watch().map((r) => r.map((d) => d.trackId).toSet());

  Future<DownloadRow?> downloadFor(String trackId) =>
      (select(downloads)..where((d) => d.trackId.equals(trackId)))
          .getSingleOrNull();

  Future<void> saveDownload(
    Track t, {
    required String path,
    required double sizeMb,
    required String quality,
  }) async {
    await upsertTrack(t);
    await into(downloads).insertOnConflictUpdate(
      DownloadsCompanion.insert(
        trackId: t.id,
        path: path,
        sizeMb: sizeMb,
        quality: quality,
      ),
    );
  }

  Future<void> removeDownload(String trackId) =>
      (delete(downloads)..where((d) => d.trackId.equals(trackId))).go();

  // ---- Backup ------------------------------------------------------------

  Future<Map<String, dynamic>> exportData() async {
    final ids = <String>{};
    final playlistRows = await (select(playlists)
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .get();
    final outPlaylists = <Map<String, dynamic>>[];
    for (final p in playlistRows) {
      final items = await playlistTracksOnce(p.id);
      ids.addAll(items.map((t) => t.id));
      outPlaylists.add({
        'name': p.name,
        'createdAt': p.createdAt.toIso8601String(),
        'tracks': items.map((t) => t.id).toList(),
      });
    }
    final likedRows = await (select(liked)
          ..orderBy([(l) => OrderingTerm.asc(l.likedAt)]))
        .get();
    final historyRows = await (select(history)
          ..orderBy([(h) => OrderingTerm.asc(h.playedAt)]))
        .get();
    final playRows = await (select(plays)
          ..orderBy([(p) => OrderingTerm.asc(p.playedAt)]))
        .get();
    ids
      ..addAll(likedRows.map((l) => l.trackId))
      ..addAll(historyRows.map((h) => h.trackId))
      ..addAll(playRows.map((p) => p.trackId));
    final trackRows = ids.isEmpty
        ? <TrackRow>[]
        : await (select(tracks)..where((t) => t.id.isIn(ids))).get();
    return {
      'app': 'yumusic',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tracks': trackRows.map((r) => _toTrack(r).toJson()).toList(),
      'playlists': outPlaylists,
      'liked': likedRows
          .map((l) => {'id': l.trackId, 'at': l.likedAt.toIso8601String()})
          .toList(),
      'history': historyRows
          .map((h) => {'id': h.trackId, 'at': h.playedAt.toIso8601String()})
          .toList(),
      'plays': playRows
          .map((p) => {'id': p.trackId, 'at': p.playedAt.toIso8601String()})
          .toList(),
    };
  }

  /// Menggabungkan isi backup ke data yang ada (tidak menghapus apa pun).
  /// Melempar [FormatException] bila file bukan backup Yumusic.
  Future<void> importData(Map<String, dynamic> data) async {
    if (data['app'] != 'yumusic' || data['tracks'] is! List) {
      throw const FormatException('Bukan file backup Yumusic');
    }
    final byId = <String, Track>{
      for (final j in (data['tracks'] as List).cast<Map<String, dynamic>>())
        j['id'] as String: Track.fromJson(j),
    };
    DateTime when(Object? v) =>
        DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

    await transaction(() async {
      final existing = {
        for (final p in await select(playlists).get()) p.name: p.id,
      };
      for (final p
          in ((data['playlists'] as List?) ?? []).cast<Map<String, dynamic>>()) {
        final name = p['name'] as String;
        final id = existing[name] ??
            await createPlaylist(name, createdAt: when(p['createdAt']));
        final items = [
          for (final tid in (p['tracks'] as List).cast<String>())
            if (byId[tid] != null) byId[tid]!,
        ];
        await addToPlaylist(id, items);
      }
      for (final l
          in ((data['liked'] as List?) ?? []).cast<Map<String, dynamic>>()) {
        final t = byId[l['id']];
        if (t != null) await setLiked(t, true, at: when(l['at']));
      }
      for (final h
          in ((data['history'] as List?) ?? []).cast<Map<String, dynamic>>()) {
        final t = byId[h['id']];
        if (t != null) await addHistory(t, at: when(h['at']));
      }
      // Putaran yang sudah ada (waktu dan lagu sama) tidak digandakan.
      final known = {
        for (final p in await select(plays).get())
          '${p.trackId}|${p.playedAt.millisecondsSinceEpoch ~/ 1000}',
      };
      for (final p
          in ((data['plays'] as List?) ?? []).cast<Map<String, dynamic>>()) {
        final t = byId[p['id']];
        final at = when(p['at']);
        if (t == null || !known.add('${t.id}|${at.millisecondsSinceEpoch ~/ 1000}')) {
          continue;
        }
        await upsertTrack(t);
        await recordPlay(t.id, at: at);
      }
    });
  }
}
