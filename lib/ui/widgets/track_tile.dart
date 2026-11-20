import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../player/downloads.dart';
import '../../providers.dart';
import '../dialogs.dart';

class Cover extends StatelessWidget {
  const Cover({super.key, required this.url, this.size = 48, this.radius = 6});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: size * 0.5),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.playlistId,
  });

  final Track track;
  final VoidCallback onTap;

  /// Bila diisi, menu menampilkan "Hapus dari playlist".
  final int? playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent =
        ref.watch(currentTrackProvider.select((t) => t?.id == track.id));
    final isDownloaded = ref.watch(
      downloadedIdsProvider.select((d) => d.value?.contains(track.id) ?? false),
    );
    final progress =
        ref.watch(downloadManagerProvider.select((m) => m[track.id]));

    return ListTile(
      leading: Cover(url: track.thumbnailUrl),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? TextStyle(color: scheme.primary) : null,
      ),
      subtitle: Row(
        children: [
          if (progress != null) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress > 0 ? progress : null,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (isDownloaded) ...[
            Icon(Icons.download_done, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              track.durationSec > 0
                  ? '${track.artist} · ${formatDuration(track.duration)}'
                  : track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => showTrackMenu(context, track, playlistId: playlistId),
      ),
      onTap: onTap,
      onLongPress: () => showTrackMenu(context, track, playlistId: playlistId),
    );
  }
}

Future<void> startDownload(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final s = ref.read(stringsProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(downloadManagerProvider.notifier).download(track);
    messenger.showSnackBar(SnackBar(content: Text(s.downloaded)));
  } on WifiRequiredException {
    messenger.showSnackBar(SnackBar(content: Text(s.wifiRequired)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(s.downloadFailed)));
  }
}

void showTrackMenu(BuildContext context, Track track, {int? playlistId}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Consumer(
      builder: (_, ref, _) {
        final s = ref.watch(stringsProvider);
        final handler = ref.read(audioHandlerProvider);
        final db = ref.read(databaseProvider);
        final isLiked = ref.watch(likedIdsProvider).contains(track.id);
        final isDownloaded =
            ref.watch(downloadedIdsProvider).value?.contains(track.id) ?? false;
        final messenger = ScaffoldMessenger.of(context);

        void close([String? message]) {
          Navigator.pop(sheet);
          if (message != null) {
            messenger.showSnackBar(SnackBar(content: Text(message)));
          }
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Cover(url: track.thumbnailUrl),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(s.playNext),
                onTap: () {
                  handler.playNext(track);
                  close(s.willPlayNext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(s.addToQueue),
                onTap: () {
                  handler.addToQueue(track);
                  close(s.addedToQueue);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(s.addToPlaylist),
                onTap: () {
                  close();
                  showAddToPlaylist(context, track);
                },
              ),
              ListTile(
                leading: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                title: Text(isLiked ? s.unlike : s.like),
                onTap: () {
                  db.setLiked(track, !isLiked);
                  close();
                },
              ),
              ListTile(
                leading: Icon(
                  isDownloaded ? Icons.delete_outline : Icons.download_outlined,
                ),
                title: Text(isDownloaded ? s.removeDownload : s.download),
                onTap: () {
                  close();
                  if (isDownloaded) {
                    ref.read(downloadManagerProvider.notifier).remove(track.id);
                  } else {
                    startDownload(context, ref, track);
                  }
                },
              ),
              if (playlistId != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(s.removeFromPlaylist),
                  onTap: () {
                    db.removeFromPlaylist(playlistId, track.id);
                    close();
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}

void showAddToPlaylist(BuildContext context, Track track) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Consumer(
      builder: (_, ref, _) {
        final s = ref.watch(stringsProvider);
        final db = ref.read(databaseProvider);
        final playlists = ref.watch(playlistsProvider).value ?? const [];
        final messenger = ScaffoldMessenger.of(context);

        Future<void> add(int id, String name) async {
          final added = await db.addToPlaylist(id, [track]);
          messenger.showSnackBar(
            SnackBar(
              content: Text(added > 0 ? s.addedTo(name) : s.alreadyIn(name)),
            ),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(s.newPlaylist),
                onTap: () async {
                  Navigator.pop(sheet);
                  final name = await promptText(
                    context,
                    title: s.newPlaylist,
                    label: s.playlistName,
                    confirm: s.create,
                    cancel: s.cancel,
                  );
                  if (name == null) return;
                  await add(await db.createPlaylist(name), name);
                },
              ),
              for (final p in playlists)
                ListTile(
                  leading: Cover(url: p.coverUrl),
                  title: Text(p.name),
                  subtitle: Text(s.songs(p.count)),
                  onTap: () {
                    Navigator.pop(sheet);
                    add(p.id, p.name);
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}
