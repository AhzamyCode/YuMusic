import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../player/sleep.dart';
import '../../providers.dart';

/// Ikon sleep timer di layar Now Playing; menyala bila timer aktif.
class SleepButton extends ConsumerWidget {
  const SleepButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    return ValueListenableBuilder<SleepTimerState?>(
      valueListenable: handler.sleepTimer,
      builder: (context, timer, _) => IconButton(
        tooltip: s.sleepTimer,
        isSelected: timer != null,
        icon: const Icon(Icons.bedtime_outlined),
        selectedIcon: Icon(
          Icons.bedtime,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () => showSleepTimerSheet(context),
      ),
    );
  }
}

void showSleepTimerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Consumer(
      builder: (_, ref, _) {
        final s = ref.watch(stringsProvider);
        final handler = ref.read(audioHandlerProvider);
        final active = handler.sleepTimer.value != null;

        void set({Duration? after, bool endOfTrack = false}) {
          handler.setSleepTimer(after: after, endOfTrack: endOfTrack);
          Navigator.pop(sheet);
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  s.sleepTimer,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  s.sleepHint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final minutes in const [5, 15, 30, 45])
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(s.sleepMinutes(minutes)),
                  onTap: () => set(after: Duration(minutes: minutes)),
                ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(s.sleepHour),
                onTap: () => set(after: const Duration(hours: 1)),
              ),
              ListTile(
                leading: const Icon(Icons.music_off_outlined),
                title: Text(s.sleepEndOfTrack),
                onTap: () => set(endOfTrack: true),
              ),
              if (active)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text(s.sleepOff),
                  onTap: () => set(),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Sisa waktu sleep timer, di judul layar Now Playing.
class SleepLabel extends ConsumerStatefulWidget {
  const SleepLabel({super.key});

  @override
  ConsumerState<SleepLabel> createState() => _SleepLabelState();
}

class _SleepLabelState extends ConsumerState<SleepLabel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final handler = ref.read(audioHandlerProvider);
    return ValueListenableBuilder<SleepTimerState?>(
      valueListenable: handler.sleepTimer,
      builder: (context, timer, _) {
        if (timer == null) return const SizedBox.shrink();
        final endsAt = timer.endsAt;
        final text = endsAt == null
            ? s.sleepAtEnd
            : s.sleepIn(
                formatDuration(
                  endsAt.difference(DateTime.now()) +
                      const Duration(milliseconds: 999),
                ),
              );
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showSleepTimerSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bedtime,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}
