import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/settings.dart';
import 'player/audio_handler.dart';
import 'providers.dart';
import 'source/newpipe_source.dart';
import 'ui/diagnostics_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final db = AppDatabase();
  final source = NewPipeSource();

  final handler = await AudioService.init(
    builder: () => YuAudioHandler(
      source: source,
      db: db,
      settings: settings,
      prefs: prefs,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.yumusic.playback',
      androidNotificationChannelName: 'Yumusic',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );

  // Build diagnosa (`--dart-define=AUTO_DIAG=true`): uji tiap tahap saat app
  // dibuka dan tulis hasilnya ke logcat.
  if (const bool.fromEnvironment('AUTO_DIAG')) {
    unawaited(
      Diagnostics(
        db: db,
        source: source,
        handler: handler,
        settings: settings.value,
        // ignore: avoid_print
        write: (line) => print('YUDIAG $line'),
      ).run(),
    );
  }

  runApp(
    ProviderScope(
      // Kegagalan jaringan ditangani UI dengan tombol "Coba lagi".
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        musicSourceProvider.overrideWithValue(source),
        audioHandlerProvider.overrideWithValue(handler),
        settingsStoreProvider.overrideWithValue(settings),
      ],
      child: const YumusicApp(),
    ),
  );
}
