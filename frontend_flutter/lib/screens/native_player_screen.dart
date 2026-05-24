import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers/anime_providers.dart';
import '../services/content_service.dart';
import '../services/auto_resolve.dart';
import '../services/watch_history.dart';
import '../theme.dart';
import '../widgets/skip_intro_button.dart';

/// Native player — supports MP4 and HLS natively, no WebView, no ads.
class NativePlayerScreen extends ConsumerStatefulWidget {
  const NativePlayerScreen({
    super.key,
    required this.animeTitle,
    required this.episodeName,
    required this.videoUrl,
    required this.serverName,
    this.serverEnlace = '',
    this.episodeUrl = '',
    this.animeUrl = '',
    this.animeImage = '',
    this.animeStatus = '',
    this.qualities = const [],
    this.episodios = const [],
    this.currentEpisodeIndex = 0,
    this.onSwitchToWebView,
  });

  final String animeTitle;
  final String episodeName;
  final String videoUrl;
  final String serverName;
  final String serverEnlace;
  final String episodeUrl;
  final String animeUrl;
  final String animeImage;
  final String animeStatus;
  final List<Map<String, dynamic>> qualities;
  final List<Map<String, dynamic>> episodios;
  final int currentEpisodeIndex;
  final VoidCallback? onSwitchToWebView;

  @override
  ConsumerState<NativePlayerScreen> createState() =>
      _NativePlayerScreenState();
}

class _NativePlayerScreenState extends ConsumerState<NativePlayerScreen>
    with WidgetsBindingObserver {
  static const _chan = MethodChannel('com.anime/orientation');
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  late final Player _player;
  late final VideoController _videoController;

  // Reactive state driven by player streams
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _bufferNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  bool _isInitialized = false;

  // Stream subscriptions
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _bufSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;

  bool _loading = true;
  bool _showUI = true;
  bool _hasError = false;
  bool _switchingToWebView = false;
  bool _isFitted = false;
  bool _isReloading = false;
  bool _handlingError = false;
  double _playbackSpeed = 1.0;
  String? _errorMsg;
  late String _currentUrl;
  late String _episodeName;
  late String _episodeUrl;
  late int _epIdx;
  late List<Map<String, dynamic>> _currentQualities;
  bool _changingEpisode = false;
  bool _isDraggingSlider = false;
  bool _markedWatched = false; // true once episode is marked watched (≥90%)
  bool get _animeIsFinished =>
      widget.animeStatus.toLowerCase().contains('finaliz');

  Timer? _hideTimer;
  Timer? _progressTimer;
  double _lastSavedProgress = -1;
  // Valor visual mientras el usuario arrastra el slider; evita que el
  // stream de posición pise la UI hasta que el seek se haya completado.
  double? _dragValue;
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _kSeekCooldown = Duration(milliseconds: 1500);
  bool _bestServerRecorded = false;

  // ── Load-once guard ───────────────────────────────────────────────
  // _initControllerActive: mutex — only one open() runs at a time.
  // _videoReady: set to true after seek+play completes for this episode.
  //   While true, error-triggered reloads are suppressed for _kReadyCooldown.
  //   Reset to false only when switching episodes or quality.
  // _readyAt: timestamp when _videoReady was last set — used for cooldown.
  bool _initControllerActive = false;
  bool _videoReady = false;
  DateTime _readyAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _kReadyCooldown = Duration(seconds: 12);
  int _openSerial = 0;

  // App lifecycle — al volver del background, mpv puede emitir errores
  // espurios por la pérdida del surface de video. Suprimimos reloads en esa
  // ventana y solo llamamos play() para reanudar sin reinicializar.
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  DateTime _resumedAt = DateTime.now();
  bool _wasPlayingBeforeBackground = false;
  static const _kResumeGrace = Duration(seconds: 8);

  // Intro skip
  double? _introStart;
  double? _introEnd;
  bool _showSkipIntro = false;

  // Adjacent-episode prefetch cache: epUrl → (directUrl, qualities)
  final _prefetch = <String, ({String url, List<Map<String, dynamic>> sources})>{};

  bool get _hasPrev =>
      widget.episodios.isNotEmpty && _epIdx < widget.episodios.length - 1;
  bool get _hasNext => widget.episodios.isNotEmpty && _epIdx > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[PLAYER] initState — hashCode=$hashCode url=${widget.videoUrl}');
    _player = Player();
    _videoController = VideoController(_player);

    _currentUrl = widget.videoUrl;
    _episodeName = widget.episodeName;
    _episodeUrl = widget.episodeUrl;
    _epIdx = widget.currentEpisodeIndex;
    _currentQualities = List.from(widget.qualities);

    _setupStreams();
    WakelockPlus.enable();
    _forceLandscape();
    _startProgressSaving();
    _loadIntroSkip(_episodeUrl);

    // Initial load
    _doInitialLoad();
  }

  Future<void> _doInitialLoad() async {
    final success = await _initController(_currentUrl);
    if (!success && mounted && !_handlingError) {
      _handlingError = true;
      _smartReload();
    }
  }

  void _setupStreams() {
    _posSub = _player.stream.position.listen((pos) {
      if (!mounted) return;
      final secs = pos.inMilliseconds / 1000.0;
      final inIntro = _introStart != null &&
          _introEnd != null &&
          secs >= _introStart! &&
          secs <= _introEnd!;
      // Actualiza campo interno; rebuild solo si la UI está visible o si
      // cambia la visibilidad del botón de skip intro. Evita rebuild del
      // Video widget en cada tick mientras el usuario está mirando.
      // Cooldown post-seek: ignora posiciones del stream que aún son
      // anteriores al seek (evita rebote visible al soltar el slider).
      final seekActive =
          DateTime.now().difference(_lastSeekAt) < _kSeekCooldown;
      final seekLanded = seekActive &&
          (pos.inMilliseconds - _position.inMilliseconds).abs() < 2000;
      if (!seekActive || seekLanded) {
        _position = pos;
        _positionNotifier.value = pos;
        if (seekLanded) {
          _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }
      if (inIntro != _showSkipIntro) {
        setState(() => _showSkipIntro = inIntro);
      }
      // Mark watched once the user reaches 90% of the episode
      if (!_markedWatched && _isInitialized) {
        final durSecs = _duration.inMilliseconds / 1000.0;
        final remainingSecs = durSecs - secs;
        final nearEndByRatio = durSecs > 0 && secs / durSecs >= 0.90;
        final nearEndByTime = durSecs > 0 && remainingSecs <= 60;
        if (nearEndByRatio || nearEndByTime) {
          _markedWatched = true;
          WatchHistory.markEpisodeWatched(_episodeUrl);
          WatchHistory.handleEpisodeFinished(
            widget.animeUrl,
            animeIsFinished: _animeIsFinished,
          );
          WatchHistory.clearEpisodeProgress(_episodeUrl);
        }
      }
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (!mounted) return;
      _duration = dur;
      _durationNotifier.value = dur;
      if (dur != Duration.zero) _isInitialized = true;
    });
    _bufSub = _player.stream.buffer.listen((buf) {
      if (!mounted) return;
      _bufferNotifier.value = buf;
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      _isPlaying = playing;
      _isPlayingNotifier.value = playing;
      // Al confirmarse reproducción, guarda este servidor como preferido
      // para este episodio. Solo una vez por instancia del reproductor.
      if (playing && !_bestServerRecorded) {
        _bestServerRecorded = true;
        if (widget.serverEnlace.isNotEmpty && widget.episodeUrl.isNotEmpty) {
          unawaited(saveBestServer(widget.episodeUrl, widget.serverEnlace));
          setAnimePreferredServer(widget.animeUrl, widget.serverName);
        }
      }
    });
    _errorSub = _player.stream.error.listen((error) {
      if (error.isEmpty || !mounted) return;
      // A load is already in progress — this error belongs to that attempt.
      // _initController is handling it; a second open() would reset position.
      if (_initControllerActive) {
        debugPrint('[PLAYER] #$_openSerial error suppressed (load in progress): $error');
        return;
      }
      // App en background o recién reanudada: mpv emite errores espurios al
      // perder/recrear el surface de video. No recargamos en esa ventana.
      if (_lifecycle != AppLifecycleState.resumed ||
          DateTime.now().difference(_resumedAt) < _kResumeGrace) {
        debugPrint('[PLAYER] #$_openSerial error suppressed (lifecycle): $error');
        return;
      }
      // Cooldown after the video was successfully ready: libmpv fires non-fatal
      // errors during seek buffering that must not trigger a reload.
      final cooldownAge = DateTime.now().difference(_readyAt);
      if (_videoReady && cooldownAge < _kReadyCooldown) {
        debugPrint('[PLAYER] #$_openSerial error suppressed (cooldown ${cooldownAge.inMilliseconds}ms): $error');
        return;
      }
      debugPrint('[PLAYER] #$_openSerial error → smartReload: $error');
      if (!_hasError && !_handlingError && !_isReloading && !_loading) {
        _handlingError = true;
        _smartReload();
      }
    });
  }

  Future<void> _forceLandscape() async {
    try {
      await _chan.invokeMethod('forceLandscape');
    } catch (_) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _resetOrientation() async {
    try {
      await _chan.invokeMethod('resetOrientation');
    } catch (_) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Controller init ───────────────────────────────────────────────

  /// Open [url] in the player. Returns true on success, false on failure.
  /// Does NOT auto-fallback — callers decide what to do on failure.
  Future<bool> _initController(String url, {Duration? seekTo}) async {
    if (!mounted) return false;
    if (_initControllerActive) {
      debugPrint('[PLAYER] open($url) BLOCKED — already loading');
      return false;
    }
    _initControllerActive = true;
    _videoReady = false;
    setState(() {
      _loading = true;
      _hasError = false;
      _errorMsg = null;
      _isInitialized = false;
    });

    // ── 1. Determine resume target BEFORE opening ────────────────
    Duration? target = seekTo;
    if (target == null && _episodeUrl.isNotEmpty) {
      final pos = await WatchHistory.getEpisodeProgress(_episodeUrl);
      debugPrint('[PLAYER] db lookup ep=$_episodeUrl → pos=$pos');
      if (pos != null && pos > 5) {
        target = Duration(milliseconds: (pos * 1000).toInt());
      }
    }
    final hasResume = target != null;

    // ── 2. Open media ────────────────────────────────────────────
    final completer = Completer<bool>();
    StreamSubscription<Duration>? durSub;
    StreamSubscription<String>? errSub;

    void complete(bool value) {
      if (!completer.isCompleted) {
        completer.complete(value);
        durSub?.cancel();
        errSub?.cancel();
      }
    }

    durSub = _player.stream.duration.listen((dur) {
      if (dur != Duration.zero) complete(true);
    });
    // Record errors just for logs, do NOT abort immediately because libmpv 
    // emits many non-fatal FFmpeg warnings (e.g. missing SPS) here.
    errSub = _player.stream.error.listen((err) {
      if (err.isNotEmpty) {
        debugPrint('[PLAYER] non-fatal init warning: $err');
      }
    });

    try {
      _openSerial++;
      final serial = _openSerial;

      // Mute during resume so the user doesn't hear audio from pos 0.
      if (hasResume) await _player.setVolume(0);

      debugPrint('[PLAYER] #$serial open(play:true) → $url');
      await _player.open(
        Media(url, httpHeaders: const {'User-Agent': _ua}),
        play: true, // Pipeline active immediately — required for seek on HTTP
      );

      final success = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () { complete(false); return false; },
      );

      if (!mounted || !success) {
        if (hasResume) await _player.setVolume(100);
        _initControllerActive = false;
        if (mounted) setState(() => _loading = false);
        return false;
      }

      // ── 3. Seek if resuming ─────────────────────────────────────
      if (hasResume && mounted) {
        final resumeTo = target;
        debugPrint('[PLAYER] #$serial resuming to ${resumeTo.inSeconds}s');
        _lastSavedProgress = resumeTo.inMilliseconds / 1000.0;

        // Wait until mpv is actually playing (position > 0) — confirms
        // the network pipeline is active and can accept a seek.
        try {
          await _player.stream.position
              .firstWhere((p) => p > Duration.zero)
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          debugPrint('[PLAYER] #$serial timed out waiting for pos>0');
        }

        if (mounted) {
          await _player.seek(resumeTo);
          debugPrint('[PLAYER] #$serial seek command sent');

          // Wait until position is near the target — confirms mpv
          // completed the seek (HTTP range request landed).
          try {
            await _player.stream.position
                .firstWhere((p) => (p - resumeTo).abs() < const Duration(seconds: 10))
                .timeout(const Duration(seconds: 8));
          } catch (_) {
            debugPrint('[PLAYER] #$serial timed out waiting for seek confirm');
          }
        }

        // Unmute
        await _player.setVolume(100);
        debugPrint('[PLAYER] #$serial resume done, unmuted');
      }

      // ── 4. Ready ────────────────────────────────────────────────
      _markedWatched = false;
      _videoReady = true;
      _readyAt = DateTime.now();

      if (mounted) {
        setState(() => _loading = false);
        _scheduleHide();
        _prefetchAdjacent();
      }
      _initControllerActive = false;
      return true;
    } catch (e) {
      debugPrint('[PLAYER] open failed: $e');
      complete(false);
      _initControllerActive = false;
      if (hasResume) _player.setVolume(100);
      if (mounted) setState(() => _loading = false);
      return false;
    }
  }

  // ── Smart reload ──────────────────────────────────────────────────

  Future<void> _smartReload() async {
    if (_isReloading || !mounted) return;

    _videoReady = false;
    _initControllerActive = false; // Reset mutex — we WANT a new open() here.

    final posSeconds = _position.inSeconds;
    final savedPos = (_isInitialized && posSeconds > 5) ? _position : null;
    debugPrint('[PLAYER] #$_openSerial smartReload pos=${posSeconds}s → savedPos=$savedPos initialized=$_isInitialized');

    // Fast path: if the video NEVER initialized (first load failed), skip
    // expensive server-scanning and go straight to WebView.
    if (!_isInitialized && widget.onSwitchToWebView != null) {
      debugPrint('[PLAYER] first load failed → instant WebView fallback');
      _handlingError = false;
      _autoFallbackToWebView();
      return;
    }

    setState(() {
      _isReloading = true;
      _hasError = false;
      _errorMsg = null;
    });

    // Step 1 — retry same URL
    if (await _initController(_currentUrl, seekTo: savedPos)) {
      _finishReload();
      return;
    }

    // Step 2 — try other quality variants of the same server
    for (final q in _currentQualities) {
      final qUrl = (q['url'] ?? '').toString();
      if (qUrl.isEmpty || qUrl == _currentUrl) continue;
      if (await _initController(qUrl, seekTo: savedPos)) {
        _currentUrl = qUrl;
        _finishReload();
        return;
      }
    }

    // Step 3 — try other servers for this episode (limit to top 3 for speed)
    if (_episodeUrl.isNotEmpty) {
      try {
        final service = ref.read(contentServiceProvider);
        final raw    = await service.getSources(_episodeUrl);
        final sorted = ContentService.sortServersByPriority(raw);

        for (final srv in sorted.take(3)) {
          final enlace = (srv['enlace'] ?? '').toString();
          if (enlace.isEmpty) continue;
          try {
            final sources = await service.resolveDirectUrl(enlace);
            if (sources.isEmpty) continue;
            final url = sources.last['url']?.toString() ?? '';
            if (url.isEmpty) continue;
            if (await _initController(url, seekTo: savedPos)) {
              _currentUrl = url;
              if (mounted) setState(() => _currentQualities = List.from(sources));
              _finishReload();
              return;
            }
          } catch (_) {
            continue;
          }
        }
      } catch (_) {}
    }

    // All failed — auto-fallback a WebView si está disponible
    if (mounted && widget.onSwitchToWebView != null) {
      _handlingError = false;
      _autoFallbackToWebView();
      return;
    }
    if (mounted) {
      setState(() {
        _isReloading = false;
        _loading = false;
        _hasError = true;
        _errorMsg = 'No se encontró ninguna fuente disponible';
      });
    }
    _handlingError = false;
  }

  void _finishReload() {
    if (mounted) setState(() => _isReloading = false);
    _handlingError = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prev = _lifecycle;
    _lifecycle = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (prev == AppLifecycleState.resumed) {
        _wasPlayingBeforeBackground = _isPlaying;
        _saveProgress(force: true);
        if (_isPlaying) _player.pause();
      }
    } else if (state == AppLifecycleState.resumed &&
        prev != AppLifecycleState.resumed) {
      _resumedAt = DateTime.now();
      if (_wasPlayingBeforeBackground && !_loading && !_hasError) {
        _player.play();
      }
    }
  }

  @override
  void dispose() {
    debugPrint('[PLAYER] dispose — hashCode=$hashCode pos=${_position.inSeconds}s');
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _saveProgress(force: true);
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _bufferNotifier.dispose();
    _isPlayingNotifier.dispose();
    _player.dispose();
    WakelockPlus.disable();
    // No resetear orientación si vamos al WebView — él maneja la suya.
    if (!_switchingToWebView) _resetOrientation();
    super.dispose();
  }

  // ── UI auto-hide ──────────────────────────────────────────────────

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_isDraggingSlider) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isDraggingSlider) {
        setState(() => _showUI = false);
      }
    });
  }

  // ── Progress persistence ──────────────────────────────────────────

  void _startProgressSaving() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress({bool force = false}) async {
    if (_episodeUrl.isEmpty || !_isInitialized || _loading) return;
    final position = _position.inMilliseconds / 1000.0;
    final duration = _duration.inMilliseconds / 1000.0;
    if (duration <= 0) return;

    // Throttle: only save when position changed by ≥3s (or forced).
    final diff = (position - _lastSavedProgress).abs();
    if (!force && _lastSavedProgress >= 0 && diff < 3) return;

    _lastSavedProgress = position;
    debugPrint('[PLAYER] saveProgress pos=${position.toStringAsFixed(1)}s dur=${duration.toStringAsFixed(0)}s ep=$_episodeUrl');
    await WatchHistory.saveEpisodeProgress(
      episodeUrl: _episodeUrl,
      position: position,
      duration: duration,
    );
  }

  // ── Controls ──────────────────────────────────────────────────────

  void _autoFallbackToWebView() {
    if (_switchingToWebView) return;
    _switchingToWebView = true;
    Navigator.pop(context);
    widget.onSwitchToWebView!();
  }

  void _toggleFit() {
    setState(() => _isFitted = !_isFitted);
    _scheduleHide();
  }

  void _togglePlay() {
    _isPlaying ? _player.pause() : _player.play();
    _scheduleHide();
  }

  void _seekRelative(int seconds) {
    final maxMs = _duration.inMilliseconds;
    final targetMs =
        (_position.inMilliseconds + seconds * 1000).clamp(0, maxMs == 0 ? 1 : maxMs);
    final target = Duration(milliseconds: targetMs);
    _lastSeekAt = DateTime.now();
    _position = target;
    _positionNotifier.value = target;
    _player.seek(target);
    _scheduleHide();
  }

  Future<void> _switchQuality(String url) async {
    if (url == _currentUrl) return;
    final pos = _position;
    _currentUrl = url;
    _videoReady = false;
    _initControllerActive = false; // allow the new open
    await _initController(url, seekTo: pos);
  }

  Future<void> _changeEpisode(int newIdx) async {
    if (_changingEpisode) return;
    if (newIdx < 0 || newIdx >= widget.episodios.length) return;

    _changingEpisode = true;
    _videoReady = false;
    _initControllerActive = false; // allow the new open
    _saveProgress(force: true);

    final ep = widget.episodios[newIdx];
    final epUrl = (ep['url'] ?? '').toString();
    final epName = (ep['episodio'] ?? 'Episodio').toString();

    setState(() {
      _loading = true;
      _hasError = false;
      _errorMsg = null;
    });

    // Fast path: use prefetched result if available
    final hit = _prefetch.remove(epUrl);
    if (hit != null && hit.url.isNotEmpty) {
      WatchHistory.add(
        titulo: widget.animeTitle,
        url: widget.animeUrl,
        imagen: widget.animeImage,
        lastEpisodeUrl: epUrl,
        lastEpisodeName: epName,
        lastKnownEpisodeCount: widget.episodios.length,
      );
      _lastSavedProgress = -1;
      setState(() {
        _epIdx = newIdx;
        _episodeName = epName;
        _episodeUrl = epUrl;
        _currentQualities = List.from(hit.sources);
        _introStart = null;
        _introEnd = null;
        _showSkipIntro = false;
      });
      _currentUrl = hit.url;
      final success = await _initController(hit.url);
      _loadIntroSkip(epUrl);
      _changingEpisode = false;
      if (!success && mounted && !_handlingError) {
        _handlingError = true;
        _smartReload();
      }
      return;
    }

    try {
      final service    = ref.read(contentServiceProvider);
      final servidores = await service.getSources(epUrl);

      WatchHistory.add(
        titulo: widget.animeTitle,
        url: widget.animeUrl,
        imagen: widget.animeImage,
        lastEpisodeUrl: epUrl,
        lastEpisodeName: epName,
        lastKnownEpisodeCount: widget.episodios.length,
      );

      final sorted = ContentService.sortServersByPriority(servidores);

      for (final srv in sorted) {
        final enlace = (srv['enlace'] ?? '').toString();
        if (enlace.isEmpty) continue;
        try {
          final sources = await service.resolveDirectUrl(enlace);
          if (sources.isEmpty) continue;
          final best = sources.last['url']?.toString() ?? '';
          if (best.isEmpty) continue;
          if (!mounted) break;
          _lastSavedProgress = -1;
          setState(() {
            _epIdx = newIdx;
            _episodeName = epName;
            _episodeUrl = epUrl;
            _currentQualities = List.from(sources);
            _introStart = null;
            _introEnd = null;
            _showSkipIntro = false;
          });
          _currentUrl = best;
          final success = await _initController(best);
          _loadIntroSkip(epUrl);
          _changingEpisode = false;
          if (!success && mounted && !_handlingError) {
            _handlingError = true;
            _smartReload();
          }
          return;
        } catch (_) {
          continue;
        }
      }

      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo cargar $epName en modo nativo',
              style: GoogleFonts.sora(fontSize: 13)),
          backgroundColor: VoidTheme.card,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al cambiar episodio',
              style: GoogleFonts.sora(fontSize: 13)),
          backgroundColor: VoidTheme.card,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    _changingEpisode = false;
  }

  // ── Adjacent prefetch ─────────────────────────────────────────────

  /// Kick off background resolution for the next and previous episodes.
  /// Results land in [_prefetch] and [ContentService._resolvedCache] so that
  /// [_changeEpisode] can skip all network work when the user taps next/prev.
  void _prefetchAdjacent() {
    if (widget.episodios.isEmpty) return;
    final service = ref.read(contentServiceProvider);
    for (final idx in [_epIdx + 1, _epIdx - 1]) {
      if (idx < 0 || idx >= widget.episodios.length) continue;
      final epUrl = (widget.episodios[idx]['url'] ?? '').toString();
      if (epUrl.isEmpty || _prefetch.containsKey(epUrl)) continue;
      _prefetchEpisode(service, epUrl);
    }
  }

  Future<void> _prefetchEpisode(ContentService service, String epUrl) async {
    try {
      final servers = await service.getSources(epUrl);
      final sorted  = ContentService.sortServersByPriority(servers);
      for (final srv in sorted.take(3)) {
        final enlace = (srv['enlace'] ?? '').toString();
        if (enlace.isEmpty) continue;
        final sources = await service.resolveDirectUrl(enlace);
        if (sources.isEmpty) continue;
        final url = (sources.last['url'] ?? '').toString();
        if (url.isEmpty) continue;
        if (mounted) _prefetch[epUrl] = (url: url, sources: sources);
        return;
      }
    } catch (_) {}
  }

  // ── Intro skip ────────────────────────────────────────────────────

  Future<void> _loadIntroSkip(String epUrl) async {
    if (epUrl.isEmpty) return;
    final service = ref.read(contentServiceProvider);
    final skip = await service.getIntroSkip(epUrl);
    if (!mounted) return;
    setState(() {
      _introStart = skip?.start;
      _introEnd   = skip?.end;
    });
  }

  void _skipIntro() {
    if (_introEnd == null) return;
    _player.seek(Duration(milliseconds: (_introEnd! * 1000).toInt()));
    _scheduleHide();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video — always present; black until media loads.
            // RepaintBoundary aísla al Video de los repaints de overlays
            // (barra de progreso, UI) para evitar lag en la reproducción.
            RepaintBoundary(
              child: Video(
                controller: _videoController,
                controls: (state) => const SizedBox.shrink(),
                fill: Colors.black,
                fit: _isFitted ? BoxFit.cover : BoxFit.contain,
              ),
            ),

            // Loading spinner
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: VoidTheme.primary),
              ),

            // Error overlay
            if (_hasError) _buildErrorOverlay(),

            // UI overlay (top bar + bottom bar)
            if (_showUI && !_hasError) ...[
              _buildTopBar(),
              _buildBottomBar(),
            ],

            // Skip intro button — isolated widget to avoid full-tree rebuilds
            if (!_hasError)
              SkipIntroButton(
                visible: _showSkipIntro,
                onSkip: _skipIntro,
                bottom: 120,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  _episodeName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isReloading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white70, size: 22),
                  tooltip: 'Recargar',
                  onPressed: _smartReload,
                ),
              IconButton(
                icon: const Icon(Icons.fit_screen_rounded,
                    color: Colors.white70, size: 22),
                tooltip: 'Ajustar pantalla',
                onPressed: _toggleFit,
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded,
                    color: Colors.white70, size: 22),
                onPressed: _showSettingsSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _positionNotifier,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: _durationNotifier,
          builder: (context, duration, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: _bufferNotifier,
              builder: (context, buffer, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isPlayingNotifier,
                  builder: (context, isPlaying, _) => _buildBottomBarContent(
                    position: position,
                    duration: duration,
                    buffer: buffer,
                    isPlaying: isPlaying,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBarContent({
    required Duration position,
    required Duration duration,
    required Duration buffer,
    required bool isPlaying,
  }) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Progress bar ──
              Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: GoogleFonts.sora(
                      color: VoidTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: VoidTheme.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: VoidTheme.primary,
                          overlayColor:
                              VoidTheme.primary.withValues(alpha: 0.2),
                          secondaryActiveTrackColor: Colors.white30,
                        ),
                        child: Slider(
                          min: 0,
                          max: duration.inMilliseconds
                              .toDouble()
                              .clamp(1, double.infinity),
                          value: (_dragValue ??
                                  position.inMilliseconds.toDouble())
                              .clamp(0, duration.inMilliseconds.toDouble()),
                          secondaryTrackValue: buffer.inMilliseconds
                              .toDouble()
                              .clamp(0, duration.inMilliseconds.toDouble()),
                          onChangeStart: (v) {
                            _hideTimer?.cancel();
                            setState(() {
                              _isDraggingSlider = true;
                              _dragValue = v;
                            });
                          },
                          onChanged: (v) {
                            // Solo UI; no spameamos seek en libmpv.
                            setState(() => _dragValue = v);
                          },
                          onChangeEnd: (v) {
                            _lastSeekAt = DateTime.now();
                            _position = Duration(milliseconds: v.toInt());
                            _positionNotifier.value = _position;
                            _player.seek(_position);
                            setState(() {
                              _isDraggingSlider = false;
                              _dragValue = null;
                            });
                            _scheduleHide();
                          },
                        ),
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: GoogleFonts.sora(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // ── Transport controls ──
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded,
                          color: _hasNext ? Colors.white : Colors.white24,
                          size: 32),
                      onPressed:
                          _hasNext ? () => _changeEpisode(_epIdx - 1) : null,
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.fast_rewind_rounded,
                          color: Colors.white, size: 32),
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: _togglePlay,
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.fast_forward_rounded,
                          color: Colors.white, size: 32),
                      onPressed: () => _seekRelative(10),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded,
                          color: _hasPrev ? Colors.white : Colors.white24,
                          size: 32),
                      onPressed:
                          _hasPrev ? () => _changeEpisode(_epIdx + 1) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: VoidTheme.pink, size: 48),
          const SizedBox(height: 12),
          Text(
            'No se pudo reproducir',
            style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _errorMsg ?? 'Error desconocido',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _isReloading ? null : _smartReload,
                icon: _isReloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white70),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_isReloading ? 'Buscando\u2026' : 'Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
              if (widget.onSwitchToWebView != null) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _autoFallbackToWebView,
                  icon: const Icon(Icons.web_rounded, size: 18),
                  label: const Text('WebView'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VoidTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // ── Quality section ──
                    if (_currentQualities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.hd_rounded,
                                color: VoidTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Calidad',
                                style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._currentQualities.map((q) {
                        final label = (q['label'] ?? '?').toString();
                        final url = (q['url'] ?? '').toString();
                        final active = url == _currentUrl;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            active
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color:
                                active ? VoidTheme.primary : Colors.white38,
                            size: 20,
                          ),
                          title: Text(label,
                              style: GoogleFonts.sora(
                                color: active
                                    ? VoidTheme.primary
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              )),
                          onTap: () {
                            Navigator.pop(ctx);
                            _switchQuality(url);
                          },
                        );
                      }),
                      const Divider(
                          color: Colors.white12,
                          height: 24,
                          indent: 20,
                          endIndent: 20),
                    ],
                    // ── Speed section ──
                    if (_currentQualities.isEmpty) const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded,
                              color: VoidTheme.cyan, size: 20),
                          const SizedBox(width: 8),
                          Text('Velocidad',
                              style: GoogleFonts.sora(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      final active = _playbackSpeed == speed;
                      final label = speed == 1.0 ? 'Normal' : '${speed}x';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: active ? VoidTheme.cyan : Colors.white38,
                          size: 20,
                        ),
                        title: Text(label,
                            style: GoogleFonts.sora(
                              color: active ? VoidTheme.cyan : Colors.white,
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                        onTap: () {
                          setState(() => _playbackSpeed = speed);
                          setSheetState(() {});
                          _player.setRate(speed);
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
