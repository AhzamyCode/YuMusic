import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../source/music_source.dart';

/// Pengaturan app. Tersimpan di SharedPreferences.
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.dynamicColor = true,
    this.language = 'system',
    this.qualityWifi = AudioQuality.high,
    this.qualityMobile = AudioQuality.medium,
    this.downloadWifiOnly = true,
    this.autoRadio = true,
    this.songsOnly = true,
  });

  final ThemeMode themeMode;
  final bool dynamicColor;

  /// `system`, `id`, atau `en`.
  final String language;
  final AudioQuality qualityWifi;
  final AudioQuality qualityMobile;
  final bool downloadWifiOnly;
  final bool autoRadio;
  final bool songsOnly;

  Settings copyWith({
    ThemeMode? themeMode,
    bool? dynamicColor,
    String? language,
    AudioQuality? qualityWifi,
    AudioQuality? qualityMobile,
    bool? downloadWifiOnly,
    bool? autoRadio,
    bool? songsOnly,
  }) =>
      Settings(
        themeMode: themeMode ?? this.themeMode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        language: language ?? this.language,
        qualityWifi: qualityWifi ?? this.qualityWifi,
        qualityMobile: qualityMobile ?? this.qualityMobile,
        downloadWifiOnly: downloadWifiOnly ?? this.downloadWifiOnly,
        autoRadio: autoRadio ?? this.autoRadio,
        songsOnly: songsOnly ?? this.songsOnly,
      );
}

/// Dipakai juga oleh audio handler (di luar Riverpod), jadi dibuat sebagai
/// [ValueNotifier] biasa.
class SettingsStore extends ValueNotifier<Settings> {
  SettingsStore(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  static Settings _read(SharedPreferences p) {
    const d = Settings();
    return Settings(
      themeMode: _enum(ThemeMode.values, p.getString('themeMode'), d.themeMode),
      dynamicColor: p.getBool('dynamicColor') ?? d.dynamicColor,
      language: p.getString('language') ?? d.language,
      qualityWifi:
          _enum(AudioQuality.values, p.getString('qualityWifi'), d.qualityWifi),
      qualityMobile: _enum(
        AudioQuality.values,
        p.getString('qualityMobile'),
        d.qualityMobile,
      ),
      downloadWifiOnly: p.getBool('downloadWifiOnly') ?? d.downloadWifiOnly,
      autoRadio: p.getBool('autoRadio') ?? d.autoRadio,
      songsOnly: p.getBool('songsOnly') ?? d.songsOnly,
    );
  }

  void update(Settings s) {
    value = s;
    _prefs
      ..setString('themeMode', s.themeMode.name)
      ..setBool('dynamicColor', s.dynamicColor)
      ..setString('language', s.language)
      ..setString('qualityWifi', s.qualityWifi.name)
      ..setString('qualityMobile', s.qualityMobile.name)
      ..setBool('downloadWifiOnly', s.downloadWifiOnly)
      ..setBool('autoRadio', s.autoRadio)
      ..setBool('songsOnly', s.songsOnly);
  }
}
