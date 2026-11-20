import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../providers.dart';
import '../../source/music_source.dart';
import '../genre_page.dart';
import '../remote_tracks_page.dart';
import 'track_tile.dart';

const pagePadding = 20.0;

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          pagePadding,
          28,
          action == null ? pagePadding : 8,
          action == null ? 12 : 4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

/// Kartu cover dengan judul di bawahnya, untuk deretan mendatar.
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.size = 136,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(url: imageUrl, size: size, radius: 12),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deretan kartu yang digeser ke samping.
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.children, this.height = 190});
  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: pagePadding),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, i) => children[i],
        ),
      );
}

/// Kotak abu-abu yang tampil selagi deretan kartu dimuat.
class CardRowPlaceholder extends StatelessWidget {
  const CardRowPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return CardRow(
      children: [
        for (var i = 0; i < 4; i++)
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

class PlaylistCard extends ConsumerWidget {
  const PlaylistCard(this.playlist, {super.key});
  final PlaylistLink playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CoverCard(
        title: playlist.name,
        subtitle: playlist.by,
        imageUrl: playlist.thumbnailUrl,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RemoteTracksPage(
              title: playlist.name,
              subtitle: playlist.by,
              coverUrl: playlist.thumbnailUrl,
              loader: (source) async =>
                  (await source.playlist(playlist.url)).tracks,
            ),
          ),
        ),
      );
}

/// Album di hasil pencarian; dibuka seperti playlist, diputar berurutan.
class AlbumCard extends StatelessWidget {
  const AlbumCard(this.album, {super.key});
  final PlaylistLink album;

  @override
  Widget build(BuildContext context) => CoverCard(
        title: album.name,
        subtitle: album.by,
        imageUrl: album.thumbnailUrl,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RemoteTracksPage(
              title: album.name,
              subtitle: album.by,
              coverUrl: album.thumbnailUrl,
              loader: (source) async =>
                  (await source.playlist(album.url)).tracks,
            ),
          ),
        ),
      );
}

/// Katalog genre dan suasana, dua kolom.
class GenreGrid extends ConsumerWidget {
  const GenreGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(stringsProvider).isId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: pagePadding),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: [
          for (final genre in catalog)
            Material(
              color: genre.color,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => GenrePage(genre)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          genre.label(isId),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        genre.icon,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
