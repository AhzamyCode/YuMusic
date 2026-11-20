import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/recommend.dart';
import '../data/settings.dart';
import '../models/track.dart';
import '../source/music_source.dart';
import 'sleep.dart';

enum PlayerErrorKind { streamFailed, stopped, radioFailed }

class PlayerError {
  const PlayerError(this.kind, this.title, [this.detail = '']);
  final PlayerErrorKind kind;

  /// Alasan teknis singkat, untuk membantu melacak masalah.
  final String detail;
  final String title;
}

Future<AudioQuality> currentQuality(Settings s) async {
  try {
    final c = await Connectivity().checkConnectivity();
    final unmetered = c.contains(ConnectivityResult.wifi) ||
        c.contains(ConnectivityResult.ethernet);
    return unmetered ? s.qualityWifi : s.qualityMobile;
  } catch (_) {
    return s.qualityMobile;
  }
}

/// Pemutar + antrean. Antrean dikelola sendiri (bukan playlist bawaan
/// just_audio) karena URL stream baru diambil tepat sebelum lagu diputar.
class YuAudioHandler extends BaseAudioHandler with SeekHandler {
  YuAudioHandler({
    required this.source,
    required this.db,
    required this.settings,
    required this.prefs,
  }) {
    _init();
  }

  final MusicSource source;
  final AppDatabase db;
  final SettingsStore settings;
  final SharedPreferences prefs;

  static const _stateKey = 'player_state';
  static const _maxFailures = 3;

  // Server audio YouTube mengharapkan user-agent yang sama dengan yang dipakai
  // saat URL-nya dicari.
  // Tanpa proxy: just_audio kalau tidak akan melewatkan audio lewat
  // http://127.0.0.1, yang diblokir Android sebagai HTTP tanpa enkripsi.
  late final _player = AudioPlayer(
    userAgent: source.userAgent,
    useProxyForRequestHeaders: false,
  );
  final _errors = StreamController<PlayerError>.broadcast();
  final _random = Random();

  /// Pesan error untuk ditampilkan UI.
  Stream<PlayerError> get errors => _errors.stream;

  /// Beberapa error terakhir beserta alasannya, untuk layar diagnosa.
  final recentErrors = <String>[];

  void _remember(String title, Object? error) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    recentErrors.add('  $time "$title": ${error ?? 'tidak diketahui'}');
    if (recentErrors.length > 10) recentErrors.removeAt(0);
  }

  List<MediaItem> _items = [];
  int _index = -1;

  /// Urutan asli sebelum diacak, untuk dikembalikan saat shuffle dimatikan.
  List<MediaItem>? _unshuffled;
  bool _shuffle = false;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;

  /// Apakah lagu di [_index] sudah dimuat ke player.
  bool _loaded = false;
  bool _resolving = false;
  Duration _pendingPosition = Duration.zero;
  int _loadToken = 0;
  int _failures = 0;
  bool _retriedCurrent = false;
  bool _fetchingRadio = false;

  /// Lagu yang terakhir dipilih pengguna sendiri. Radio mengambil dari mix
  /// lagu ini, bukan dari lagu radio terakhir, supaya genrenya tidak bergeser
  /// makin jauh tiap kali antrean diperpanjang.
  MediaItem? _radioSeed;

  /// Lagu yang putarannya sudah dicatat sejak terakhir dimuat.
  String? _countedId;

  /// Sleep timer yang aktif, untuk ditampilkan UI; null bila mati.
  final sleepTimer = ValueNotifier<SleepTimerState?>(null);
  Timer? _sleepTick;

  /// Menyalakan sleep timer: berhenti setelah [after], atau di akhir lagu
  /// bila [endOfTrack]. Tanpa keduanya, sleep timer dimatikan.
  void setSleepTimer({Duration? after, bool endOfTrack = false}) {
    _sleepTick?.cancel();
    _sleepTick = null;
    unawaited(_player.setVolume(1));
    if (endOfTrack) {
      sleepTimer.value = const SleepTimerState.endOfTrack();
    } else if (after != null) {
      final endsAt = DateTime.now().add(after);
      sleepTimer.value = SleepTimerState.at(endsAt);
      _sleepTick = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _sleepStep(endsAt),
      );
    } else {
      sleepTimer.value = null;
    }
  }

  void _sleepStep(DateTime endsAt) {
    final left = endsAt.difference(DateTime.now());
    if (left > Duration.zero) {
      final volume = sleepVolume(left);
      if (_player.volume != volume) unawaited(_player.setVolume(volume));
      return;
    }
    _sleepTick?.cancel();
    _sleepTick = null;
    sleepTimer.value = null;
    unawaited(_sleepNow());
  }

  Future<void> _sleepNow() async {
    await pause();
    // Volume dikembalikan setelah berhenti, supaya putaran berikutnya normal.
    await _player.setVolume(1);
  }

  void _countPlay(Duration position) {
    final item = _current;
    if (item == null || !_loaded || _countedId == item.id) return;
    if (position < playCountThreshold(item.duration)) return;
    _countedId = item.id;
    unawaited(db.recordPlay(item.id));
  }
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  MediaItem? get _current =>
      _index >= 0 && _index < _items.length ? _items[_index] : null;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.becomingNoisyEventStream.listen((_) => pause());

    _player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e, StackTrace _) {
        debugPrint('Yumusic: error pemutaran: $e');
        _onPlaybackError(e);
      },
    );
    _player.playingStream.listen((_) {
      _broadcast();
      _save(force: true);
    });
    _player.positionStream.listen((position) {
      _save();
      _countPlay(position);
    });
    _player.durationStream.listen((d) {
      final item = _current;
      if (d == null || item == null || !_loaded || item.duration == d) return;
      _items[_index] = item.copyWith(duration: d);
      mediaItem.add(_items[_index]);
      queue.add(List.of(_items));
    });
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && _loaded) _onCompleted();
    });
    _restore();
  }

  // ---- State ke sistem & UI ---------------------------------------------

  void _broadcast() {
    final playing = _player.playing && _loaded || _resolving;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _resolving
            ? AudioProcessingState.loading
            : !_loaded
                // Idle = belum ada yang dimuat; service & notifikasi boleh mati.
                ? AudioProcessingState.idle
                : switch (_player.processingState) {
                    ProcessingState.idle => AudioProcessingState.idle,
                    ProcessingState.loading => AudioProcessingState.loading,
                    ProcessingState.buffering => AudioProcessingState.buffering,
                    ProcessingState.ready => AudioProcessingState.ready,
                    ProcessingState.completed => AudioProcessingState.completed,
                  },
        playing: playing,
        updatePosition: _loaded ? _player.position : _pendingPosition,
        bufferedPosition: _loaded ? _player.bufferedPosition : Duration.zero,
        speed: _player.speed,
        queueIndex: _index < 0 ? null : _index,
        shuffleMode: _shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _repeat,
      ),
    );
  }

  void _publishQueue() {
    queue.add(List.of(_items));
    mediaItem.add(_current);
    _broadcast();
    _save(force: true);
  }

  // ---- Simpan & pulihkan -------------------------------------------------

  void _save({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) {
      return;
    }
    _lastSave = now;
    final position = _loaded ? _player.position : _pendingPosition;
    prefs.setString(
      _stateKey,
      jsonEncode({
        'queue': _items.map((m) => Track.fromMediaItem(m).toJson()).toList(),
        'index': _index,
        'position': position.inMilliseconds,
        'shuffle': _shuffle,
        'repeat': _repeat.name,
      }),
    );
  }

  void _restore() {
    final raw = prefs.getString(_stateKey);
    if (raw == null) return _broadcast();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _items = (j['queue'] as List)
          .cast<Map<String, dynamic>>()
          .map((t) => Track.fromJson(t).toMediaItem())
          .toList();
      final i = (j['index'] as num?)?.toInt() ?? -1;
      _index = _items.isEmpty ? -1 : i.clamp(0, _items.length - 1);
      _pendingPosition =
          Duration(milliseconds: (j['position'] as num?)?.toInt() ?? 0);
      _shuffle = j['shuffle'] == true;
      _repeat = AudioServiceRepeatMode.values
              .where((r) => r.name == j['repeat'])
              .firstOrNull ??
          AudioServiceRepeatMode.none;
    } catch (_) {
      _items = [];
      _index = -1;
    }
    queue.add(List.of(_items));
    mediaItem.add(_current);
    _broadcast();
  }

  // ---- Memuat lagu -------------------------------------------------------

  Future<AudioSource> _resolve(String id) async {
    final dl = await db.downloadFor(id);
    if (dl != null) {
      if (File(dl.path).existsSync()) return AudioSource.file(dl.path);
      await db.removeDownload(id);
    }
    final quality = await currentQuality(settings.value);
    // URL diberikan langsung ke pemutar, yang mengambil audionya sendiri.
    final stream = await source.resolve(id, quality);
    return AudioSource.uri(stream.url);
  }

  Future<void> _load(
    int index, {
    bool play = true,
    Duration position = Duration.zero,
    bool isRetry = false,
  }) async {
    if (index < 0 || index >= _items.length) return;
    final token = ++_loadToken;
    final item = _items[index];
    _index = index;
    _loaded = false;
    _resolving = true;
    _pendingPosition = position;
    if (!isRetry) {
      _retriedCurrent = false;
      _countedId = null;
    }
    mediaItem.add(item);
    _broadcast();
    try {
      // Diamkan lagu sebelumnya supaya tidak terus bunyi selama URL dicari.
      await _player.pause();
      final audio = await _resolve(item.id);
      if (token != _loadToken) return;
      await _player.setAudioSource(audio, initialPosition: position);
      if (token != _loadToken) return;
      _loaded = true;
      _resolving = false;
      _failures = 0;
      _broadcast();
      _save(force: true);
      if (play) unawaited(_player.play());
      unawaited(db.addHistory(Track.fromMediaItem(item)));
    } catch (e) {
      debugPrint('Yumusic: gagal memuat ${item.id}: $e');
      if (token != _loadToken) return;
      _resolving = false;
      await _failed(item, e);
    }
  }

  static String _describe(Object? error) {
    final text = switch (error) {
      null => '',
      PlatformException(:final code, :final message) => '$code: $message',
      _ => error.toString(),
    };
    final line = text.split('\n').first.trim();
    return line.length > 140 ? '${line.substring(0, 140)}…' : line;
  }

  /// Lagu gagal dimuat: beri tahu UI lalu lompat ke lagu berikutnya. Berhenti
  /// setelah beberapa kali gagal berturut-turut (mis. koneksi putus).
  Future<void> _failed(MediaItem item, [Object? error]) async {
    final detail = _describe(error);
    _remember(item.title, error);
    source.invalidate(item.id);
    _failures++;
    final next = _nextIndex();
    if (_failures >= _maxFailures || next == null || next == _index) {
      _failures = 0;
      _errors.add(PlayerError(PlayerErrorKind.stopped, item.title, detail));
      await _player.stop();
      _broadcast();
      return;
    }
    _errors.add(PlayerError(PlayerErrorKind.streamFailed, item.title, detail));
    await _load(next);
  }

  /// Error di tengah lagu, biasanya URL kedaluwarsa: ambil URL baru sekali,
  /// lanjut dari posisi terakhir.
  Future<void> _onPlaybackError(Object error) async {
    final item = _current;
    if (item == null || !_loaded) return;
    source.invalidate(item.id);
    if (!_retriedCurrent) {
      _retriedCurrent = true;
      await _load(_index, position: _player.position, isRetry: true);
    } else {
      _loaded = false;
      await _failed(item, error);
    }
  }

  int? _nextIndex() {
    if (_items.isEmpty) return null;
    if (_index + 1 < _items.length) return _index + 1;
    return _repeat == AudioServiceRepeatMode.all ? 0 : null;
  }

  Future<void> _onCompleted() async {
    if (sleepTimer.value?.endOfTrack ?? false) {
      sleepTimer.value = null;
      await _player.pause();
      await _player.seek(Duration.zero);
      return;
    }
    if (_repeat == AudioServiceRepeatMode.one) {
      _countedId = null;
      await _player.seek(Duration.zero);
      return _player.play();
    }
    final next = _nextIndex();
    if (next != null) return _load(next);
    if (settings.value.autoRadio && await _extendWithRadio()) {
      return _load(_index + 1);
    }
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  /// Menambah lagu terkait ke akhir antrean. True bila ada yang ditambahkan.
  Future<bool> _extendWithRadio({bool showLoading = true}) async {
    final item = _current;
    if (item == null || _fetchingRadio) return false;
    _fetchingRadio = true;
    if (showLoading) {
      _resolving = true;
      _broadcast();
    }
    try {
      final known = _items.map((m) => m.id).toSet();
      var fresh = <Track>[];
      final seeds = <MediaItem>[
        if (_radioSeed != null && _radioSeed!.id != item.id) _radioSeed!,
        item,
      ];
      for (final seed in seeds) {
        final related = await source.related(Track.fromMediaItem(seed));
        fresh = pickRadio(related, known);
        if (fresh.isNotEmpty) break;
      }
      if (fresh.isEmpty) return false;
      _items.addAll(fresh.map((t) => t.toMediaItem()));
      _unshuffled?.addAll(fresh.map((t) => t.toMediaItem()));
      _publishQueue();
      return true;
    } catch (_) {
      _errors.add(PlayerError(PlayerErrorKind.radioFailed, item.title));
      return false;
    } finally {
      _fetchingRadio = false;
      if (showLoading) {
        _resolving = false;
        _broadcast();
      }
    }
  }

  // ---- Antrean -----------------------------------------------------------

  /// Mengganti antrean dengan [tracks] dan mulai memutar dari [index].
  /// Memutar satu lagu lalu mengisi antrean dengan lagu yang mirip (mix
  /// lagu itu), bukan dengan lagu lain di daftar asalnya. Dipakai untuk hasil
  /// pencarian: yang berikutnya diputar harus mirip lagu pilihan, bukan hasil
  /// pencarian di bawahnya.
  Future<void> playWithRadio(Track track) async {
    _items = [track.toMediaItem()];
    _index = 0;
    _unshuffled = null;
    _radioSeed = _items.first;
    _publishQueue();
    await _load(0);
    // Diisi setelah lagu mulai, supaya suara tidak menunggu daftar radio.
    if (_current?.id == track.id && _items.length == 1) {
      await _extendWithRadio(showLoading: false);
    }
  }

  Future<void> playTracks(
    List<Track> tracks, {
    int index = 0,
    bool shuffle = false,
  }) async {
    if (tracks.isEmpty) return;
    final seen = <String>{};
    final start = tracks[index.clamp(0, tracks.length - 1)];
    final unique = tracks.where((t) => seen.add(t.id)).toList();
    _items = unique.map((t) => t.toMediaItem()).toList();
    _index = unique.indexOf(start);
    _radioSeed = _items[_index];
    _unshuffled = null;
    if (shuffle) {
      _index = _random.nextInt(_items.length);
      _shuffle = true;
    }
    if (_shuffle) _shuffleUpcoming();
    _publishQueue();
    await _load(_index);
  }

  void _shuffleUpcoming() {
    _unshuffled = List.of(_items);
    final current = _current;
    final rest = List.of(_items)..remove(current);
    rest.shuffle(_random);
    _items = [?current, ...rest];
    _index = current == null ? -1 : 0;
  }

  void _removeById(String id) {
    final i = _items.indexWhere((m) => m.id == id);
    if (i < 0 || i == _index) return;
    _items.removeAt(i);
    if (i < _index) _index--;
    _unshuffled?.removeWhere((m) => m.id == id);
  }

  /// Menaruh lagu tepat setelah lagu yang sedang diputar.
  Future<void> playNext(Track track) async {
    if (_items.isEmpty) return playTracks([track]);
    if (_current?.id == track.id) return;
    _removeById(track.id);
    final item = track.toMediaItem();
    _items.insert(_index + 1, item);
    _unshuffled?.add(item);
    _publishQueue();
  }

  Future<void> addToQueue(Track track) async {
    if (_items.isEmpty) return playTracks([track]);
    if (_items.any((m) => m.id == track.id)) return;
    final item = track.toMediaItem();
    _items.add(item);
    _unshuffled?.add(item);
    _publishQueue();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);
    _unshuffled?.removeWhere((m) => m.id == removed.id);
    if (index < _index) {
      _index--;
    } else if (index == _index) {
      final wasPlaying = _player.playing;
      if (_items.isEmpty) {
        _index = -1;
        _loaded = false;
        _loadToken++;
        await _player.stop();
      } else {
        _index = _index.clamp(0, _items.length - 1);
        _publishQueue();
        return _load(_index, play: wasPlaying);
      }
    }
    _publishQueue();
  }

  void moveQueueItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    final current = _current;
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex.clamp(0, _items.length), item);
    if (current != null) _index = _items.indexOf(current);
    _publishQueue();
  }

  // ---- Kontrol -----------------------------------------------------------

  @override
  Future<void> play() async {
    if (_current == null) return;
    if (!_loaded) {
      if (_resolving) return;
      return _load(_index, position: _pendingPosition);
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() async {
    if (_resolving && !_loaded) {
      // Batalkan pemuatan yang sedang berjalan.
      _loadToken++;
      _resolving = false;
      _broadcast();
      return;
    }
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_loaded) {
      _pendingPosition = position;
      _broadcast();
      return;
    }
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    var next = _nextIndex();
    if (next == null && settings.value.autoRadio && await _extendWithRadio()) {
      next = _index + 1;
    }
    if (next != null) await _load(next);
  }

  @override
  Future<void> skipToPrevious() async {
    final position = _loaded ? _player.position : _pendingPosition;
    if (position > const Duration(seconds: 3) || _index <= 0) {
      return seek(Duration.zero);
    }
    await _load(_index - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) {
    if (index >= 0 && index < _items.length) _radioSeed = _items[index];
    return _load(index);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final on = shuffleMode != AudioServiceShuffleMode.none;
    if (on == _shuffle) return;
    _shuffle = on;
    final current = _current;
    if (on) {
      _shuffleUpcoming();
    } else if (_unshuffled != null) {
      _items = _unshuffled!;
      _unshuffled = null;
      if (current != null) {
        _index = _items.indexWhere((m) => m.id == current.id);
      }
    }
    _publishQueue();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode == AudioServiceRepeatMode.group
        ? AudioServiceRepeatMode.all
        : repeatMode;
    _broadcast();
    _save(force: true);
  }

  @override
  Future<void> stop() async {
    _loadToken++;
    _resolving = false;
    if (_loaded) _pendingPosition = _player.position;
    _loaded = false;
    _save(force: true);
    await _player.stop();
    _broadcast();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    // App digeser dari recent: lanjut main bila sedang main, selain itu
    // matikan service supaya notifikasi tidak tertinggal.
    if (!_player.playing) await stop();
  }
}
