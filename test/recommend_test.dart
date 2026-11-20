import 'package:flutter_test/flutter_test.dart';
import 'package:yumusic/data/recommend.dart';
import 'package:yumusic/models/track.dart';

Track track(String id, String artist) => Track(
      id: id,
      title: 'Lagu $id',
      artist: artist,
      durationSec: 200,
      thumbnailUrl: '',
    );

void main() {
  test('pickSeeds: satu lagu per artis, selang-seling riwayat dan disukai', () {
    final history = [track('h1', 'Tulus'), track('h2', 'tulus'), track('h3', 'Hindia')];
    final liked = [track('l1', 'Nadin Amizah'), track('l2', 'Hindia')];
    expect(
      pickSeeds(liked, history).map((t) => t.id),
      // h2 dilewati (artis sama dengan h1); Hindia sudah terwakili l2.
      ['h1', 'l1', 'l2'],
    );
    expect(pickSeeds(liked, history, max: 2).length, 2);
    expect(pickSeeds(const [], const []), isEmpty);
  });

  test('pickSeeds melewati lagu tanpa artis', () {
    expect(pickSeeds(const [], [track('a', ' '), track('b', 'Sal Priadi')]).single.id, 'b');
  });

  test('pickRadio membuang lagu yang sudah di antrean dan membatasi per artis', () {
    final candidates = [
      track('1', 'A'), track('2', 'A'), track('3', 'A'),
      track('4', 'B'), track('1', 'A'), track('5', 'C'),
    ];
    expect(
      pickRadio(candidates, {'4'}, perArtist: 2).map((t) => t.id),
      ['1', '2', '5'],
    );
    expect(pickRadio(candidates, const {}, limit: 2).length, 2);
    expect(pickRadio(candidates, {'1', '2', '3', '4', '5'}), isEmpty);
  });
}
