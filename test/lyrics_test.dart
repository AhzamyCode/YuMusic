import 'package:flutter_test/flutter_test.dart';
import 'package:yumusic/source/lyrics.dart';
import 'package:yumusic/source/newpipe_source.dart';

void main() {
  test('parseLrc membaca tanda waktu dan melewati baris lain', () {
    final lines = parseLrc(
      '[ar:Artis]\n[00:12.50]Baris satu\n[01:02.345] Baris dua\n[02:00]\n',
    );
    expect(lines.length, 3);
    expect(lines[0].time, const Duration(seconds: 12, milliseconds: 500));
    expect(lines[0].text, 'Baris satu');
    expect(
      lines[1].time,
      const Duration(minutes: 1, seconds: 2, milliseconds: 345),
    );
    expect(lines[2].text, '');
  });

  test('cleanTitle membuang embel-embel video', () {
    expect(
      cleanTitle('Tulus - Hati-Hati di Jalan (Official Music Video)', 'Tulus'),
      'Hati-Hati di Jalan',
    );
    expect(cleanTitle('Sial [Lyrics]', 'Mahalini'), 'Sial');
  });

  test('cleanArtist membuang akhiran channel', () {
    expect(NewPipeSource.cleanArtist('Tulus - Topic'), 'Tulus');
    expect(NewPipeSource.cleanArtist('NadinAmizahVEVO'), 'NadinAmizah');
    expect(NewPipeSource.cleanArtist('Hindia'), 'Hindia');
  });
}
