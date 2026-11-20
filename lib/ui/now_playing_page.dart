import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../providers.dart';
import '../source/lyrics.dart';
import 'widgets/mini_player.dart';
import 'widgets/sleep_timer.dart';
import 'widgets/track_tile.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = ref.watch(settingsProvider.select((s) => s.dynamicColor))
        ? ref.watch(coverSchemeProvider(theme.brightness)).value
        : null;
    if (cover == null) return _content(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: cover,
        scaffoldBackgroundColor: cover.surface,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: cover.surface,
          foregroundColor: cover.onSurface,
        ),
        sliderTheme: theme.sliderTheme.copyWith(
          activeTrackColor: cover.onSurface,
          thumbColor: cover.onSurface,
          inactiveTrackColor: cover.outlineVariant,
        ),
      ),
      child: Builder(builder: _content),
    );
  }

  Widget _content(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final track = ref.watch(currentTrackProvider);
    final handler = ref.read(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(s.nothingPlaying)),
      );
    }

    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final shuffle = state?.shuffleMode == AudioServiceShuffleMode.all;
    final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;
    final isLiked = ref.watch(likedIdsProvider).contains(track.id);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const SleepLabel(),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: s.lyrics,
            isSelected: _showLyrics,
            icon: const Icon(Icons.lyrics_outlined),
            selectedIcon: const Icon(Icons.lyrics),
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),
          const SleepButton(),
          IconButton(
            tooltip: s.queue,
            icon: const Icon(Icons.queue_music),
            onPressed: () => _showQueue(context),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showTrackMenu(context, track),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: _showLyrics
                    ? _LyricsView(track: track)
                    : Center(
                        child: LayoutBuilder(
                          builder: (_, box) => Cover(
                            url: track.coverUrl,
                            size: box.biggest.shortestSide,
                            radius: 16,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isLiked ? s.unlike : s.like,
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? scheme.primary : null,
                    ),
                    onPressed: () =>
                        ref.read(databaseProvider).setLiked(track, !isLiked),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SeekBar(track: track),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: s.shuffle,
                    icon: const Icon(Icons.shuffle),
                    color: shuffle ? scheme.primary : scheme.onSurfaceVariant,
                    onPressed: () => handler.setShuffleMode(
                      shuffle
                          ? AudioServiceShuffleMode.none
                          : AudioServiceShuffleMode.all,
                    ),
                  ),
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: handler.skipToPrevious,
                  ),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: isBusy(state)
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(),
                          )
                        : IconButton.filled(
                            iconSize: 40,
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: playing ? handler.pause : handler.play,
                          ),
                  ),
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next),
                    onPressed: handler.skipToNext,
                  ),
                  IconButton(
                    icon: Icon(
                      repeat == AudioServiceRepeatMode.one
                          ? Icons.repeat_one
                          : Icons.repeat,
                    ),
                    color: repeat == AudioServiceRepeatMode.none
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                    onPressed: () => handler.setRepeatMode(
                      switch (repeat) {
                        AudioServiceRepeatMode.none =>
                          AudioServiceRepeatMode.all,
                        AudioServiceRepeatMode.all =>
                          AudioServiceRepeatMode.one,
                        _ => AudioServiceRepeatMode.none,
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => _QueueList(controller: controller),
      ),
    );
  }
}

class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.track});
  final Track track;

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = widget.track.duration.inMilliseconds.toDouble();
    final max = total > 0 ? total : 1.0;
    final value =
        (_dragging ?? position.inMilliseconds.toDouble()).clamp(0.0, max);
    final style = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        Slider(
          max: max,
          value: value,
          onChanged: total > 0 ? (v) => setState(() => _dragging = v) : null,
          onChangeEnd: (v) {
            ref
                .read(audioHandlerProvider)
                .seek(Duration(milliseconds: v.round()));
            setState(() => _dragging = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: value.round())),
                style: style,
              ),
              Text(formatDuration(widget.track.duration), style: style),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    final items = ref.watch(queueProvider).value ?? const [];
    final currentId = ref.watch(currentTrackProvider.select((t) => t?.id));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${s.queue} · ${s.songs(items.length)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: controller,
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: handler.moveQueueItem,
            itemBuilder: (_, i) {
              final item = items[i];
              final current = item.id == currentId;
              return ListTile(
                key: ValueKey(item.id),
                contentPadding: const EdgeInsets.only(left: 16, right: 4),
                leading: Cover(url: item.extras?['thumb'] as String?),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: current ? TextStyle(color: scheme.primary) : null,
                ),
                subtitle: Text(
                  item.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => handler.removeQueueItemAt(i),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
                onTap: () => handler.skipToQueueItem(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LyricsView extends ConsumerWidget {
  const _LyricsView({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lyrics = ref.watch(lyricsProvider(track));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(s.noLyrics)),
      data: (l) {
        if (l == null) return Center(child: Text(s.noLyrics));
        if (!l.isSynced) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l.plain ?? '',
              style: text.titleMedium?.copyWith(height: 1.6),
            ),
          );
        }
        return _SyncedLyrics(lines: l.synced, text: text, scheme: scheme);
      },
    );
  }
}

class _SyncedLyrics extends ConsumerStatefulWidget {
  const _SyncedLyrics({
    required this.lines,
    required this.text,
    required this.scheme,
  });
  final List<LyricLine> lines;
  final TextTheme text;
  final ColorScheme scheme;

  @override
  ConsumerState<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<_SyncedLyrics> {
  static const _lineExtent = 44.0;
  final _controller = ScrollController();
  int _active = -1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final active = widget.lines.lastIndexWhere((l) => l.time <= position);
    if (active != _active) {
      _active = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        final view = _controller.position.viewportDimension;
        final target = (active * _lineExtent - view / 2 + _lineExtent / 2)
            .clamp(0.0, _controller.position.maxScrollExtent);
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }

    return ListView.builder(
      controller: _controller,
      itemExtent: _lineExtent,
      itemCount: widget.lines.length,
      itemBuilder: (_, i) {
        final line = widget.lines[i];
        final isActive = i == active;
        return InkWell(
          onTap: () => ref.read(audioHandlerProvider).seek(line.time),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              line.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.text.titleMedium?.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? widget.scheme.primary
                    : widget.scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
