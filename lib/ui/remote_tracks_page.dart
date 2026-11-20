import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../providers.dart';
import '../source/music_source.dart';
import 'widgets/home_widgets.dart';
import 'widgets/mini_player.dart';
import 'widgets/track_tile.dart';

/// Daftar lagu yang diambil dari internet: playlist rekomendasi atau mix.
class RemoteTracksPage extends ConsumerStatefulWidget {
  const RemoteTracksPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.loader,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final Future<List<Track>> Function(MusicSource source) loader;

  @override
  ConsumerState<RemoteTracksPage> createState() => _RemoteTracksPageState();
}

class _RemoteTracksPageState extends ConsumerState<RemoteTracksPage> {
  late Future<List<Track>> _tracks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _tracks = widget.loader(ref.read(musicSourceProvider));

  Future<void> _save(List<Track> tracks) async {
    final s = ref.read(stringsProvider);
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final id = await db.createPlaylist(widget.title);
    await db.addToPlaylist(id, tracks);
    messenger.showSnackBar(
      SnackBar(content: Text(s.savedToLibrary(widget.title))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: FutureBuilder<List<Track>>(
        future: _tracks,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final tracks = snapshot.data ?? const <Track>[];
          if (snapshot.hasError || tracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.hasError ? s.loadFailed : s.emptyList),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(_load),
                    child: Text(s.retry),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: tracks.length + 1,
            itemBuilder: (_, i) {
              if (i > 0) {
                return TrackTile(
                  track: tracks[i - 1],
                  onTap: () => handler.playTracks(tracks, index: i - 1),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  pagePadding,
                  4,
                  pagePadding,
                  16,
                ),
                child: Column(
                  children: [
                    Cover(url: widget.coverUrl, size: 180, radius: 16),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (widget.subtitle.isNotEmpty) widget.subtitle,
                        s.songs(tracks.length),
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(s.playAll),
                            onPressed: () => handler.playTracks(tracks),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            icon: const Icon(Icons.shuffle_rounded),
                            label: Text(s.shuffle),
                            onPressed: () =>
                                handler.playTracks(tracks, shuffle: true),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: s.saveToLibrary,
                          icon: const Icon(Icons.library_add_outlined),
                          onPressed: () => _save(tracks),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
