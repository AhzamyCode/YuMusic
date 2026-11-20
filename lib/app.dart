import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player/audio_handler.dart';
import 'providers.dart';
import 'ui/home_page.dart';
import 'ui/library_page.dart';
import 'ui/search_page.dart';
import 'ui/theme.dart';
import 'ui/widgets/mini_player.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class YumusicApp extends ConsumerWidget {
  const YumusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Yumusic',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(settingsProvider.select((s) => s.themeMode)),
      locale: ref.watch(localeProvider),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;
  StreamSubscription<PlayerError>? _errors;

  @override
  void initState() {
    super.initState();
    // Error pemutaran ditampilkan sebagai pesan, apa pun layar yang terbuka.
    _errors = ref.read(audioHandlerProvider).errors.listen((e) {
      final s = ref.read(stringsProvider);
      final message = switch (e.kind) {
        PlayerErrorKind.streamFailed => s.streamFailed(e.title),
        PlayerErrorKind.stopped => s.playbackStopped(e.title),
        PlayerErrorKind.radioFailed => s.radioFailed,
      };
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content:
                Text(e.detail.isEmpty ? message : '$message\n(${e.detail})'),
          ),
        );
    });
  }

  @override
  void dispose() {
    _errors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomePage(), SearchPage(), LibraryPage()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: s.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_rounded),
                label: s.search,
              ),
              NavigationDestination(
                icon: const Icon(Icons.library_music_outlined),
                selectedIcon: const Icon(Icons.library_music_rounded),
                label: s.library,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
