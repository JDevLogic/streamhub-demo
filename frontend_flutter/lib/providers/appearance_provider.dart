import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppVisualTheme { voidNeon, amoled }

enum AppMotionMode { normal, reduced }

enum EpisodeViewPreference { automatic, list, grid }

class AppearanceState {
  const AppearanceState({
    this.visualTheme = AppVisualTheme.voidNeon,
    this.motionMode = AppMotionMode.normal,
    this.episodeView = EpisodeViewPreference.automatic,
  });

  final AppVisualTheme visualTheme;
  final AppMotionMode motionMode;
  final EpisodeViewPreference episodeView;

  bool get isAmoled => visualTheme == AppVisualTheme.amoled;
  bool get reduceAnimations => motionMode == AppMotionMode.reduced;

  AppearanceState copyWith({
    AppVisualTheme? visualTheme,
    AppMotionMode? motionMode,
    EpisodeViewPreference? episodeView,
  }) {
    return AppearanceState(
      visualTheme: visualTheme ?? this.visualTheme,
      motionMode: motionMode ?? this.motionMode,
      episodeView: episodeView ?? this.episodeView,
    );
  }
}

class AppearanceNotifier extends StateNotifier<AppearanceState> {
  AppearanceNotifier() : super(const AppearanceState()) {
    unawaited(_load());
  }

  static const _themeKey = 'appearance_theme';
  static const _motionKey = 'appearance_motion';
  static const _episodeViewKey = 'appearance_episode_view';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppearanceState(
      visualTheme: _parseVisualTheme(prefs.getString(_themeKey)),
      motionMode: _parseMotionMode(prefs.getString(_motionKey)),
      episodeView: _parseEpisodeView(prefs.getString(_episodeViewKey)),
    );
  }

  Future<void> setVisualTheme(AppVisualTheme value) async {
    if (state.visualTheme == value) return;
    state = state.copyWith(visualTheme: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
  }

  Future<void> setMotionMode(AppMotionMode value) async {
    if (state.motionMode == value) return;
    state = state.copyWith(motionMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_motionKey, value.name);
  }

  Future<void> setEpisodeView(EpisodeViewPreference value) async {
    if (state.episodeView == value) return;
    state = state.copyWith(episodeView: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_episodeViewKey, value.name);
  }

  AppVisualTheme _parseVisualTheme(String? raw) {
    return AppVisualTheme.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => AppVisualTheme.voidNeon,
    );
  }

  AppMotionMode _parseMotionMode(String? raw) {
    return AppMotionMode.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => AppMotionMode.normal,
    );
  }

  EpisodeViewPreference _parseEpisodeView(String? raw) {
    return EpisodeViewPreference.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => EpisodeViewPreference.automatic,
    );
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppearanceState>(
  (ref) => AppearanceNotifier(),
);
