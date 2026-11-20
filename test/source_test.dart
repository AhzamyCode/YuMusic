import 'package:flutter_test/flutter_test.dart';
import 'package:yumusic/models/track.dart';
import 'package:yumusic/source/music_source.dart';
import 'package:yumusic/source/newpipe_source.dart';

void main() {
  test('expiryOf membaca parameter expire, atau 5 jam bila tidak ada', () {
    expect(
      expiryOf('https://x.googlevideo.com/videoplayback?expire=1800000000&id=1'),
      DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000),
    );
    final now = DateTime(2026, 11, 15, 10);
    expect(
      expiryOf('https://example.com/a?id=1', now: now),
      DateTime(2026, 11, 15, 15),
    );
  });

  test('withRange menaruh range di link tanpa mengubah parameter lain', () {
    final url = Uri.parse('https://x.googlevideo.com/v?sig=a%2Cb&expire=1');
    expect(
      withRange(url).toString(),
      'https://x.googlevideo.com/v?sig=a%2Cb&expire=1&range=0-',
    );
    expect(
      withRange(url, 500).toString(),
      'https://x.googlevideo.com/v?sig=a%2Cb&expire=1&range=500-',
    );
    final ranged = Uri.parse('https://x.googlevideo.com/v?sig=a&range=0-&n=2');
    expect(withRange(ranged), ranged);
    expect(
      withRange(ranged, 9).toString(),
      'https://x.googlevideo.com/v?sig=a&n=2&range=9-',
    );
    expect(
      withRange(Uri.parse('https://example.com/file')).toString(),
      'https://example.com/file?range=0-',
    );
  });

  test('ekstensi file mengikuti tipe MIME', () {
    ResolvedStream stream(String mime) => ResolvedStream(
          url: Uri.parse('https://example.com'),
          mimeType: mime,
          bitrateKbps: 128,
          expiresAt: DateTime(2030),
        );
    expect(stream('audio/webm').container, 'webm');
    expect(stream('audio/mp4').container, 'm4a');
  });

  test('cover YouTube Music diperbesar, cover video memakai hqdefault', () {
    Track track(String thumb) => Track(
          id: 'abc',
          title: 't',
          artist: 'a',
          durationSec: 1,
          thumbnailUrl: thumb,
        );
    expect(
      track('https://lh3.googleusercontent.com/xyz=w120-h120-l90-rj').coverUrl,
      'https://lh3.googleusercontent.com/xyz=w544-h544-l90-rj',
    );
    expect(
      track('https://i.ytimg.com/vi/abc/mqdefault.jpg').coverUrl,
      'https://img.youtube.com/vi/abc/hqdefault.jpg',
    );
  });
}
