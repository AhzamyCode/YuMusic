import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumusic/data/database.dart';
import 'package:yumusic/models/track.dart';

Track track(int n) => Track(
      id: 'id$n',
      title: 'Lagu $n',
      artist: 'Artis',
      durationSec: 200,
      thumbnailUrl: 'https://example.com/$n.jpg',
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('playlist menyimpan urutan dan melewati lagu ganda', () async {
    final id = await db.createPlaylist('Kerja');
    expect(await db.addToPlaylist(id, [track(1), track(2)]), 2);
    expect(await db.addToPlaylist(id, [track(2), track(3)]), 1);

    final items = await db.playlistTracksOnce(id);
    expect(items.map((t) => t.id), ['id1', 'id2', 'id3']);

    await db.removeFromPlaylist(id, 'id2');
    expect((await db.playlistTracksOnce(id)).map((t) => t.id), ['id1', 'id3']);

    final info = (await db.watchPlaylists().first).single;
    expect(info.count, 2);
    expect(info.coverUrl, 'https://example.com/1.jpg');
  });

  test('hapus playlist ikut menghapus isinya', () async {
    final id = await db.createPlaylist('A');
    await db.addToPlaylist(id, [track(1)]);
    await db.deletePlaylist(id);
    expect(await db.watchPlaylists().first, isEmpty);
    expect(await db.playlistTracksOnce(id), isEmpty);
  });

  test('riwayat dibatasi 100 lagu, terbaru dulu, tanpa duplikat', () async {
    final start = DateTime(2026, 1, 1);
    for (var i = 0; i < 105; i++) {
      await db.addHistory(track(i), at: start.add(Duration(minutes: i)));
    }
    await db.addHistory(track(50), at: start.add(const Duration(days: 1)));

    final history = await db.watchHistory().first;
    expect(history.length, historyLimit);
    expect(history.first.id, 'id50');
    expect(history.where((t) => t.id == 'id50').length, 1);
    expect(history.any((t) => t.id == 'id0'), isFalse);
  });

  test('suka bisa dinyalakan dan dimatikan', () async {
    await db.setLiked(track(1), true);
    expect(await db.watchIsLiked('id1').first, isTrue);
    await db.setLiked(track(1), false);
    expect(await db.watchLiked().first, isEmpty);
  });

  test('backup bisa dipulihkan ke database kosong', () async {
    final id = await db.createPlaylist('Favorit');
    await db.addToPlaylist(id, [track(1), track(2)]);
    await db.setLiked(track(3), true);
    await db.addHistory(track(4));

    // Lewat JSON seperti file sungguhan.
    final json = jsonDecode(jsonEncode(await db.exportData()))
        as Map<String, dynamic>;

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.importData(json);
    await other.importData(json); // impor dua kali tidak menggandakan

    final playlists = await other.watchPlaylists().first;
    expect(playlists.single.name, 'Favorit');
    expect(
      (await other.playlistTracksOnce(playlists.single.id)).map((t) => t.id),
      ['id1', 'id2'],
    );
    expect((await other.watchLiked().first).single.id, 'id3');
    expect((await other.watchHistory().first).single.id, 'id4');
  });

  test('file yang bukan backup ditolak', () {
    expect(() => db.importData({'foo': 'bar'}), throwsFormatException);
  });
}
