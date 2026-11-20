import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../now_playing_page.dart';
import 'track_tile.dart';

bool isBusy(PlaybackState? s) =>
    s != null &&
    (s.processingState == AudioProcessingState.loading ||
        s.processingState == AudioProcessingState.buffering);

/// Kartu kecil yang mengambang di atas navigasi bawah.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final handler = ref.read(audioHandlerProvider);
    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = track.duration.inMilliseconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const NowPlayingPage(),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                child: Row(
                  children: [
                    Cover(url: track.thumbnailUrl, size: 42, radius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      iconSize: 30,
                      color: scheme.onSurface,
                      onPressed: playing ? handler.pause : handler.play,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      color: scheme.onSurface,
                      onPressed: handler.skipToNext,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                value: isBusy(state)
                    ? null
                    : total > 0
                        ? (position.inMilliseconds / total).clamp(0.0, 1.0)
                        : 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
