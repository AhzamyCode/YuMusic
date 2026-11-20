import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumusic/data/database.dart';
import 'package:yumusic/models/track.dart';
import 'package:yumusic/player/sleep.dart';
import 'package:yumusic/providers.dart';

Track track(String id, String artist, {int seconds = 180}) => Track(
      id: id,
      title: 'Lagu $id',
      artist: artist,
      durationSec: seconds,
      thumbnailUrl: 'https://example.com/$id.jpg',
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 21, 12);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> play(Track t, int times, {required DateTime at}) async {
    await db.upsertTrack(t);
    for (var i = 0; i < times; i++) {
      await db.recordPlay(t.id, at: at.add(Duration(minutes: i)));
    }
  }

  test('lagu teratas dihitung per putaran, dan bisa dibatasi waktunya', () async {
    final a = track('a', 'Tulus');
    final b = track('b', 'Hindia');
    final c = track('c', 'Tulus');
    await play(a, 2, at: now.subtract(const Duration(days: 20)));
    await play(b, 3, at: now.subtract(const Duration(days: 2)));
    await play(c, 1, at: now.subtract(const Duration(days: 1)));
    await play(a, 2, at: now.subtract(const Duration(days: 1)));

    final all = await db.watchTopTracks().first;
    expect(all.map((s) => (s.track.id, s.plays)), [('a', 4), ('b', 3), ('c', 1)]);

    final week = await db
        .watchTopTracks(since: periodStart(StatsPeriod.week, now))
        .first;
    expect(week.map((s) => (s.track.id, s.plays)), [('b', 3), ('a', 2), ('c', 1)]);

    final artists = await db.watchTopArtists().first;
    expect(artists.map((x) => (x.name, x.plays)), [('Tulus', 5), ('Hindia', 3)]);

    final summary = await db.watchSummary().first;
    expect(summary.plays, 8);
    expect(summary.songs, 3);
    expect(summary.artists, 2);
    expect(summary.minutes, 8 * 3);
  });

  test('putaran ikut di backup, dan impor dua kali tidak menggandakan', () async {
    await play(track('a', 'Tulus'), 3, at: now);
    final json = jsonDecode(jsonEncode(await db.exportData()))
        as Map<String, dynamic>;

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.importData(json);
    await other.importData(json);
    final top = await other.watchTopTracks().first;
    expect(top.single.plays, 3);
  });

  test('volume sleep timer turun lurus di 30 detik terakhir', () {
    expect(sleepVolume(const Duration(minutes: 5)), 1);
    expect(sleepVolume(const Duration(seconds: 30)), 1);
    expect(sleepVolume(const Duration(seconds: 15)), 0.5);
    expect(sleepVolume(Duration.zero), 0);
    expect(sleepVolume(const Duration(seconds: -3)), 0);
  });

  test('lagu dihitung setelah 30 detik, atau separuh lagu pendek', () {
    expect(playCountThreshold(const Duration(minutes: 4)), const Duration(seconds: 30));
    expect(playCountThreshold(const Duration(seconds: 40)), const Duration(seconds: 20));
    expect(playCountThreshold(null), const Duration(seconds: 30));
  });
}
