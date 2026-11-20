import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../providers.dart';
import 'dialogs.dart';
import 'widgets/mini_player.dart';
import 'widgets/track_tile.dart';

enum TrackListKind { liked, history, downloads, playlist }

/// Daftar lagu untuk playlist, Disukai, Riwayat, dan Download.
class TrackListPage extends ConsumerWidget {
  const TrackListPage.playlist(int id, {super.key})
      : kind = TrackListKind.playlist,
        playlistId = id;
  const TrackListPage.builtin(this.kind, {super.key}) : playlistId = null;

  final TrackListKind kind;
  final int? playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    final db = ref.read(databaseProvider);

    final AsyncValue<List<Track>> tracks;
    final String title;
    switch (kind) {
      case TrackListKind.liked:
        tracks = ref.watch(likedProvider);
        title = s.liked;
      case TrackListKind.history:
        tracks = ref.watch(historyProvider);
        title = s.history;
      case TrackListKind.downloads:
        tracks = ref.watch(downloadsProvider);
        title = s.downloads;
      case TrackListKind.playlist:
        tracks = ref.watch(playlistTracksProvider(playlistId!));
        title = ref.watch(playlistProvider(playlistId!)).value?.name ?? '';
    }
    final items = tracks.value ?? const <Track>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (kind == TrackListKind.history && items.isNotEmpty)
            IconButton(
              tooltip: s.clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: db.clearHistory,
            ),
          if (kind == TrackListKind.playlist)
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'rename') {
                  final name = await promptText(
                    context,
                    title: s.rename,
                    label: s.playlistName,
                    confirm: s.save,
                    cancel: s.cancel,
                    initial: title,
                  );
                  if (name != null) await db.renamePlaylist(playlistId!, name);
                } else {
                  final ok = await confirmDialog(
                    context,
                    title: s.deletePlaylistQ(title),
                    confirm: s.delete,
                    cancel: s.cancel,
                  );
                  if (!ok) return;
                  await db.deletePlaylist(playlistId!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(s.rename)),
                PopupMenuItem(value: 'delete', child: Text(s.delete)),
              ],
            ),
        ],
      ),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: tracks.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(child: Text(s.emptyList))
              : ListView.builder(
                  itemCount: items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: Text(s.playAll),
                                onPressed: () => handler.playTracks(items),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.shuffle),
                                label: Text(s.shuffle),
                                onPressed: () =>
                                    handler.playTracks(items, shuffle: true),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return TrackTile(
                      track: items[i - 1],
                      playlistId: playlistId,
                      onTap: () => handler.playTracks(items, index: i - 1),
                    );
                  },
                ),
    );
  }
}
