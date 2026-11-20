import 'package:flutter_test/flutter_test.dart';
import 'package:yumusic/data/search_rank.dart';
import 'package:yumusic/models/track.dart';
import 'package:yumusic/source/music_source.dart';

Track track(String id, String title, String artist) => Track(
      id: id,
      title: title,
      artist: artist,
      durationSec: 200,
      thumbnailUrl: '',
    );

PlaylistLink album(String name, String by) =>
    PlaylistLink(url: 'https://music.youtube.com/$name', name: name, by: by);

void main() {
  test('dedupeTracks membuang versi ganda dan menjaga urutan', () {
    final tracks = [
      track('1', 'Hati-Hati di Jalan', 'Tulus'),
      track('2', 'Hati-hati di Jalan (Official Audio)', 'TULUS'),
      track('3', 'Monokrom', 'Tulus'),
      track('4', 'Hati-Hati di Jalan', 'Penyanyi Lain'),
    ];
    expect(dedupeTracks(tracks).map((t) => t.id), ['1', '3', '4']);
  });

  test('rankAlbums mendahulukan album yang cocok dengan semua kata', () {
    final albums = [
      album('Greatest Hits', 'Various'),
      album('Manusia', 'Tulus'),
      album('Tulus Live', 'Orang Lain'),
      album('Monokrom', 'Tulus'),
    ];
    expect(
      rankAlbums(albums, 'tulus monokrom').map((a) => a.name),
      ['Monokrom', 'Manusia', 'Tulus Live', 'Greatest Hits'],
    );
    expect(rankAlbums(albums, '  '), albums);
  });

  test('normalize membuang tanda baca dan huruf besar', () {
    expect(normalize('  Rex Orange County — "Pony"!  '), 'rex orange county pony');
  });
}
