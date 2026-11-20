import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog.dart';
import '../providers.dart';
import 'widgets/home_widgets.dart';
import 'widgets/mini_player.dart';
import 'widgets/track_tile.dart';

/// Isi satu genre: playlist di atas, lagu di bawah.
class GenrePage extends ConsumerWidget {
  const GenrePage(this.genre, {super.key});
  final Genre genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    final playlists = ref.watch(genrePlaylistsProvider(genre.query));
    final songs = ref.watch(genreSongsProvider(genre.query));
    final items = songs.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(genre.label(s.isId))),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: ListView(
        children: [
          SectionHeader(s.playlists),
          playlists.when(
            loading: () => const CardRowPlaceholder(),
            error: (_, _) => _Retry(
              text: s.loadFailed,
              label: s.retry,
              onTap: () => ref.invalidate(genrePlaylistsProvider(genre.query)),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: pagePadding),
                    child: Text(s.noResults),
                  )
                : CardRow(children: [for (final p in list) PlaylistCard(p)]),
          ),
          SectionHeader(s.songsTitle),
          if (songs.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (songs.hasError)
            _Retry(
              text: s.loadFailed,
              label: s.retry,
              onTap: () => ref.invalidate(genreSongsProvider(genre.query)),
            )
          else
            for (var i = 0; i < items.length; i++)
              TrackTile(
                track: items[i],
                onTap: () => handler.playTracks(items, index: i),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.text, required this.label, required this.onTap});
  final String text;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: pagePadding),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            TextButton(onPressed: onTap, child: Text(label)),
          ],
        ),
      );
}
