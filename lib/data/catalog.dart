import 'package:flutter/material.dart';

/// Satu ubin di katalog: genre atau suasana.
class Genre {
  const Genre(this.id, this.en, this.query, this.color, this.icon);

  /// Nama dalam bahasa Indonesia dan Inggris.
  final String id;
  final String en;

  /// Kata kunci pencarian di YouTube Music.
  final String query;
  final Color color;
  final IconData icon;

  String label(bool isId) => isId ? id : en;
}

const catalog = <Genre>[
  Genre('Pop Indonesia', 'Indonesian Pop', 'pop indonesia', Color(0xFFE8502F), Icons.star_rounded),
  Genre('Indie', 'Indie', 'indie indonesia', Color(0xFF3F7D6E), Icons.spa_rounded),
  Genre('Pop', 'Pop', 'pop hits', Color(0xFFC2477F), Icons.auto_awesome_rounded),
  Genre('Rock', 'Rock', 'rock', Color(0xFF8A3B3B), Icons.bolt_rounded),
  Genre('Hip-Hop', 'Hip-Hop', 'hip hop', Color(0xFF5B55A6), Icons.mic_rounded),
  Genre('R&B', 'R&B', 'r&b soul', Color(0xFF7A4E9E), Icons.nightlife_rounded),
  Genre('K-Pop', 'K-Pop', 'k-pop', Color(0xFF2F7FB8), Icons.favorite_rounded),
  Genre('Jazz', 'Jazz', 'jazz', Color(0xFF9A6A2F), Icons.piano_rounded),
  Genre('Dangdut', 'Dangdut', 'dangdut', Color(0xFFB5523A), Icons.celebration_rounded),
  Genre('Akustik', 'Acoustic', 'acoustic', Color(0xFF6B7F3A), Icons.music_note_rounded),
  Genre('Lo-fi', 'Lo-fi', 'lofi', Color(0xFF4A6FA5), Icons.headphones_rounded),
  Genre('Elektronik', 'Electronic', 'electronic dance', Color(0xFF2E8C8C), Icons.graphic_eq_rounded),
  Genre('Galau', 'Sad', 'lagu galau', Color(0xFF55607A), Icons.water_drop_rounded),
  Genre('Semangat', 'Workout', 'workout', Color(0xFFC96A1E), Icons.fitness_center_rounded),
  Genre('Fokus', 'Focus', 'focus music', Color(0xFF3E6B8C), Icons.self_improvement_rounded),
  Genre('Santai', 'Chill', 'chill', Color(0xFF4F8A6B), Icons.weekend_rounded),
];

/// Playlist yang ditawarkan di Home sebelum ada riwayat mendengarkan.
const starterPlaylistQueries = ['top hits indonesia', 'lagu indonesia terbaru'];
