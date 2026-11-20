import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../providers.dart';
import 'remote_tracks_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'widgets/home_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    final theme = Theme.of(context);
    final recent =
        (ref.watch(historyProvider).value ?? const <Track>[]).take(12).toList();
    final seeds = ref.watch(seedsProvider).value ?? const <Track>[];
    final playlists = ref.watch(recommendedPlaylistsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(seedsProvider);
          ref.invalidate(recommendedPlaylistsProvider);
          await ref.read(recommendedPlaylistsProvider.future);
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(pagePadding, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.greeting(DateTime.now().hour),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: s.settings,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(),
                          body: const SettingsPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const WeeklySongCard(),
            if (recent.isNotEmpty) ...[
              SectionHeader(s.recentlyPlayed),
              CardRow(
                children: [
                  for (var i = 0; i < recent.length; i++)
                    CoverCard(
                      title: recent[i].title,
                      subtitle: recent[i].artist,
                      imageUrl: recent[i].coverUrl,
                      onTap: () => handler.playTracks(recent, index: i),
                    ),
                ],
              ),
            ],
            if (seeds.isNotEmpty) ...[
              SectionHeader(s.mixesForYou),
              CardRow(
                children: [
                  for (final seed in seeds)
                    CoverCard(
                      title: s.mixOf(seed.artist),
                      subtitle: s.basedOn(seed.title),
                      imageUrl: seed.coverUrl,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RemoteTracksPage(
                            title: s.mixOf(seed.artist),
                            subtitle: s.basedOn(seed.title),
                            coverUrl: seed.coverUrl,
                            // Mix YouTube Music milik lagu acuan: isinya
                            // segenre dengan lagu itu.
                            loader: (source) async =>
                                [seed, ...await source.related(seed)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            ...playlists.when(
              loading: () => [
                SectionHeader(s.recommendedPlaylists),
                const CardRowPlaceholder(),
              ],
              error: (_, _) => const <Widget>[],
              data: (list) => list.isEmpty
                  ? const <Widget>[]
                  : [
                      SectionHeader(s.recommendedPlaylists),
                      CardRow(
                        children: [for (final p in list) PlaylistCard(p)],
                      ),
                    ],
            ),
            const MostPlayedRow(),
            SectionHeader(s.browse),
            const GenreGrid(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
