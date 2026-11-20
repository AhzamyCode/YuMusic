import 'package:audio_service/audio_service.dart';

/// Satu lagu. Yang disimpan hanya ID video; URL stream diambil ulang saat
/// akan diputar karena masa berlakunya cuma beberapa jam.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSec,
    required this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String artist;
  final int durationSec;
  final String thumbnailUrl;

  Duration get duration => Duration(seconds: durationSec);

  /// Thumbnail resolusi lebih tinggi untuk layar Now Playing. Cover dari
  /// YouTube Music membawa ukurannya di akhir URL (`=w120-h120-...`).
  String get coverUrl => thumbnailUrl.contains('googleusercontent.com')
      ? thumbnailUrl.replaceFirst(RegExp(r'=w\d+-h\d+'), '=w544-h544')
      : 'https://img.youtube.com/vi/$id/hqdefault.jpg';

  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: title,
        artist: artist,
        duration: durationSec > 0 ? duration : null,
        artUri: Uri.parse(coverUrl),
        extras: {'thumb': thumbnailUrl},
      );

  factory Track.fromMediaItem(MediaItem m) => Track(
        id: m.id,
        title: m.title,
        artist: m.artist ?? '',
        durationSec: m.duration?.inSeconds ?? 0,
        thumbnailUrl: (m.extras?['thumb'] as String?) ??
            'https://img.youtube.com/vi/${m.id}/mqdefault.jpg',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration': durationSec,
        'thumbnail': thumbnailUrl,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        artist: (j['artist'] as String?) ?? '',
        durationSec: (j['duration'] as num?)?.toInt() ?? 0,
        thumbnailUrl: (j['thumbnail'] as String?) ??
            'https://img.youtube.com/vi/${j['id']}/mqdefault.jpg',
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
