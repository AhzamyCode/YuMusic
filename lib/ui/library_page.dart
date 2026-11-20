import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'dialogs.dart';
import 'track_list_page.dart';
import 'widgets/track_tile.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  void _open(BuildContext context, Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final db = ref.read(databaseProvider);
    final name = await promptText(
      context,
      title: s.newPlaylist,
      label: s.playlistName,
      confirm: s.create,
      cancel: s.cancel,
    );
    if (name != null) await db.createPlaylist(name);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final db = ref.read(databaseProvider);
    final source = ref.read(musicSourceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final link = await promptText(
      context,
      title: s.importFromYoutube,
      label: s.playlistLink,
      confirm: s.import,
      cancel: s.cancel,
    );
    if (link == null) return;
    messenger.showSnackBar(SnackBar(content: Text(s.importing)));
    try {
      final remote = await source.playlist(link);
      if (remote.tracks.isEmpty) throw const FormatException('kosong');
      final name = remote.title.isEmpty ? s.newPlaylist : remote.title;
      final id = await db.createPlaylist(name);
      final n = await db.addToPlaylist(id, remote.tracks);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.imported(n, name))));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.importFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final likedCount = ref.watch(likedProvider).value?.length ?? 0;
    final downloadCount = ref.watch(downloadsProvider).value?.length ?? 0;
    final scheme = Theme.of(context).colorScheme;

    Widget builtin(IconData icon, String title, String? sub, TrackListKind k) =>
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          title: Text(title),
          subtitle: sub == null ? null : Text(sub),
          onTap: () => _open(context, TrackListPage.builtin(k)),
        );

    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.library,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: s.importFromYoutube,
                  icon: const Icon(Icons.link),
                  onPressed: () => _import(context, ref),
                ),
                IconButton(
                  tooltip: s.newPlaylist,
                  icon: const Icon(Icons.add),
                  onPressed: () => _create(context, ref),
                ),
              ],
            ),
          ),
          builtin(
            Icons.favorite,
            s.liked,
            s.songs(likedCount),
            TrackListKind.liked,
          ),
          builtin(
            Icons.download_done,
            s.downloads,
            s.songs(downloadCount),
            TrackListKind.downloads,
          ),
          builtin(Icons.history, s.history, null, TrackListKind.history),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              s.playlists,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.noPlaylists,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final p in playlists)
            ListTile(
              leading: Cover(url: p.coverUrl),
              title: Text(p.name),
              subtitle: Text(s.songs(p.count)),
              onTap: () => _open(context, TrackListPage.playlist(p.id)),
            ),
        ],
      ),
    );
  }
}
