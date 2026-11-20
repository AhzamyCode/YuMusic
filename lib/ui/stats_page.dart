import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets/home_widgets.dart';
import 'widgets/mini_player.dart';
import 'widgets/track_tile.dart';

void openStats(BuildContext context, StatsPeriod period) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => StatsPage(initial: period)));

/// Kartu besar di Home: lagu yang paling sering diputar 7 hari terakhir.
class WeeklySongCard extends ConsumerWidget {
  const WeeklySongCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topTracksProvider(StatsPeriod.week)).value;
    if (top == null || top.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final best = top.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(pagePadding, 20, pagePadding, 0),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color(0xFFB8336A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => openStats(context, StatsPeriod.week),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Cover(url: best.track.coverUrl, size: 76, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.songOfTheWeek.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          best.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${best.track.artist} · ${s.playedTimes(best.plays)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    iconSize: 40,
                    color: Colors.white,
                    onPressed: () => ref
                        .read(audioHandlerProvider)
                        .playWithRadio(best.track),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deretan di Home: lagu yang paling sering diputar sepanjang waktu.
class MostPlayedRow extends ConsumerWidget {
  const MostPlayedRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topTracksProvider(StatsPeriod.all)).value;
    // Baru berarti setelah ada beberapa lagu.
    if (top == null || top.length < 3) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final items = top.take(10).toList();
    final tracks = [for (final t in items) t.track];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          s.mostPlayed,
          action: s.seeAll,
          onAction: () => openStats(context, StatsPeriod.all),
        ),
        CardRow(
          children: [
            for (var i = 0; i < items.length; i++)
              CoverCard(
                title: items[i].track.title,
                subtitle: '${items[i].track.artist} · '
                    '${s.timesShort(items[i].plays)}',
                imageUrl: items[i].track.coverUrl,
                onTap: () =>
                    ref.read(audioHandlerProvider).playTracks(tracks, index: i),
              ),
          ],
        ),
      ],
    );
  }
}

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key, required this.initial});
  final StatsPeriod initial;

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  late StatsPeriod _period = widget.initial;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final handler = ref.read(audioHandlerProvider);
    final summary = ref.watch(summaryProvider(_period)).value;
    final top = ref.watch(topTracksProvider(_period)).value ?? const [];
    final artists = ref.watch(topArtistsProvider(_period)).value ?? const [];
    final tracks = [for (final t in top) t.track];

    return Scaffold(
      appBar: AppBar(title: Text(s.yourStats)),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: pagePadding),
            child: SegmentedButton<StatsPeriod>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: StatsPeriod.week, label: Text(s.periodWeek)),
                ButtonSegment(
                  value: StatsPeriod.month,
                  label: Text(s.periodMonth),
                ),
                ButtonSegment(value: StatsPeriod.all, label: Text(s.periodAll)),
              ],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.first),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: pagePadding),
            child: Row(
              children: [
                _Number(value: summary?.plays, label: s.plays),
                const SizedBox(width: 10),
                _Number(value: summary?.minutes, label: s.minutes),
                const SizedBox(width: 10),
                _Number(value: summary?.artists, label: s.artists),
              ],
            ),
          ),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.all(pagePadding * 2),
              child: Text(
                s.noStats,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            SectionHeader(
              s.topSongs,
              action: s.playAll,
              onAction: () => handler.playTracks(tracks),
            ),
            for (var i = 0; i < top.length; i++)
              _RankedTile(
                rank: i + 1,
                stat: top[i],
                plays: s.timesShort(top[i].plays),
                onTap: () => handler.playTracks(tracks, index: i),
              ),
            if (artists.isNotEmpty) ...[
              SectionHeader(s.topArtists),
              for (var i = 0; i < artists.length; i++)
                ListTile(
                  leading: SizedBox(
                    width: 76,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ClipOval(child: Cover(url: artists[i].coverUrl)),
                      ],
                    ),
                  ),
                  title: Text(artists[i].name),
                  trailing: Text(
                    s.timesShort(artists[i].plays),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({required this.value, required this.label});
  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${value ?? '–'}', style: theme.textTheme.headlineSmall),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankedTile extends StatelessWidget {
  const _RankedTile({
    required this.rank,
    required this.stat,
    required this.plays,
    required this.onTap,
  });
  final int rank;
  final TrackStat stat;
  final String plays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 76,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: rank <= 3 ? theme.colorScheme.primary : muted,
                ),
              ),
            ),
            Cover(url: stat.track.thumbnailUrl),
          ],
        ),
      ),
      title: Text(stat.track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        stat.track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(plays, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
    );
  }
}
