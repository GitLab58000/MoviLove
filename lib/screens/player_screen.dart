import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/episode_model.dart';
import '../models/movie_model.dart';
import '../services/download_service.dart';
import '../services/tmdb_service.dart';

class _EpisodeRef {
  final int season;
  final int episode;

  const _EpisodeRef(this.season, this.episode);
}

class PlayerScreen extends StatefulWidget {
  final Movie movie;

  // Тільки для серіалів
  final int? season;
  final int? episode;
  final String? episodeTitle;

  const PlayerScreen({
    super.key,
    required this.movie,
    this.season,
    this.episode,
    this.episodeTitle,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _saveTimer;
  bool _isLoading = true;
  bool _isReady = false;
  String? _errorText;

  Timer? _countdownTimer;
  late int _season;
  late int _episode;
  String? _episodeTitle;

  List<SeasonInfo> _seasons = [];

  bool _endHandled = false;
  _EpisodeRef? _nextUp;
  int _countdown = 5;

  @override
  void initState() {
    super.initState();
    _season = widget.season ?? 1;
    _episode = widget.episode ?? 1;
    _episodeTitle = widget.episodeTitle;
    _initPlayer();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    if (!widget.movie.isTv) return;
    final details = await TmdbService().getDetails(widget.movie);
    if (!mounted || details == null) return;
    setState(() => _seasons = details.seasonList);
  }

  _EpisodeRef? _computeNext() {
    if (!widget.movie.isTv || _seasons.isEmpty) return null;
    final idx = _seasons.indexWhere((s) => s.number == _season);
    if (idx == -1) return null;
    if (_episode < _seasons[idx].episodeCount) {
      return _EpisodeRef(_season, _episode + 1);
    }
    if (idx + 1 < _seasons.length) {
      return _EpisodeRef(_seasons[idx + 1].number, 1);
    }
    return null;
  }

  void _onVideoTick() {
    if (_endHandled || !_isReady) return;
    final v = _videoController?.value;
    if (v == null || !v.isInitialized) return;
    final duration = v.duration;
    if (duration <= Duration.zero) return;
    if (v.position >= duration - const Duration(milliseconds: 500) &&
        !v.isPlaying) {
      _endHandled = true;
      _onEpisodeEnded();
    }
  }

  void _onEpisodeEnded() {
    final next = _computeNext();
    if (next == null || !mounted) return;

    if (_chewieController?.isFullScreen ?? false) {
      _chewieController!.exitFullScreen();
    }

    setState(() {
      _nextUp = next;
      _countdown = 5;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        _playNext();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelNextUp() {
    _countdownTimer?.cancel();
    setState(() => _nextUp = null);
  }

  void _playNext() {
    final next = _nextUp ?? _computeNext();
    if (next == null) return;
    _playEpisode(next.season, next.episode);
  }

  // Перемикач плеєру на наступну серію
  Future<void> _playEpisode(int season, int episode) async {
    _countdownTimer?.cancel();
    _saveTimer?.cancel();
    _savePosition();
    _isReady = false;

    setState(() {
      _season = season;
      _episode = episode;
      _episodeTitle = null;
      _nextUp = null;
      _errorText = null;
      _isLoading = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    _videoController?.removeListener(_onVideoTick);
    _chewieController?.dispose();
    await _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
    if (!mounted) return;

    _endHandled = false;
    await _initPlayer(saveRightAway: true);
  }

  DocumentReference<Map<String, dynamic>>? get _historyRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .doc(widget.movie.docId);
  }

  Future<Duration> _loadSavedPosition() async {
    try {
      final snap =
      await _historyRef?.get().timeout(const Duration(seconds: 3));
      final data = snap?.data();
      if (data == null) return Duration.zero;

      if (widget.movie.isTv) {
        final savedSeason = (data['season'] as num?)?.toInt() ?? 1;
        final savedEpisode = (data['episode'] as num?)?.toInt() ?? 1;
        if (savedSeason != _season || savedEpisode != _episode) {
          return Duration.zero;
        }
      }

      final ms = (data['positionMs'] ?? 0) as num;
      return Duration(milliseconds: ms.toInt());
    } catch (_) {
      return Duration.zero;
    }
  }

  void _savePosition() {
    final controller = _videoController;
    if (!_isReady || controller == null) return;
    final ref = _historyRef;
    if (ref == null) return;

    final value = controller.value;
    final duration = value.duration;
    var position = value.position;

    if (position >= duration - const Duration(milliseconds: 500)) {
      position = Duration.zero;
    }

    final movie = widget.movie;
    ref.set({
      'movieId': movie.id,
      'mediaType': movie.mediaType,
      'title': movie.title,
      'overview': movie.overview,
      'posterPath': movie.posterPath,
      'voteAverage': movie.voteAverage,
      'releaseDate': movie.releaseDate,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      if (movie.isTv) 'season': _season,
      if (movie.isTv) 'episode': _episode,
      if (movie.isTv) 'episodeTitle': _episodeTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});
  }

  Future<void> _initPlayer({bool saveRightAway = false}) async {
    try {
      final localFile = await DownloadService.videoFile(widget.movie.id);
      if (!mounted) return;

      final VideoPlayerController controller;
      if (!widget.movie.isTv && await localFile.exists()) {
        controller = VideoPlayerController.file(localFile);
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(DownloadService.demoVideoUrl),
        );
      }
      _videoController = controller;

      await controller.initialize();
      final saved = await _loadSavedPosition();
      if (!mounted) return;

      if (widget.movie.isTv) controller.addListener(_onVideoTick);

      final duration = controller.value.duration;
      final canResume = saved > Duration.zero &&
          saved < duration - const Duration(seconds: 1);

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        startAt: canResume ? saved : null,
        aspectRatio: controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        placeholder: Container(color: Colors.black),
      );

      _isReady = true;
      _saveTimer =
          Timer.periodic(const Duration(seconds: 2), (_) => _savePosition());

      if (saveRightAway && !canResume) _savePosition();
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Не вдалось завантажити відео. Перевірте інтернет.\n$e';
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _countdownTimer?.cancel();
    _savePosition();
    _isReady = false;
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18),
            ),
            if (widget.movie.isTv)
              Text(
                '$_season сезон · $_episode серія',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
          ],
        ),
        actions: [
          if (!_isLoading && _computeNext() != null)
            IconButton(
              tooltip: 'Наступна серія',
              icon: const Icon(Icons.skip_next),
              onPressed: _playNext,
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.redAccent)
                  : _errorText != null
                  ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              )
                  : Chewie(controller: _chewieController!),
            ),
          ),
          if (_nextUp != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildNextUpCard(_nextUp!),
            ),
        ],
      ),
    );
  }


  Widget _buildNextUpCard(_EpisodeRef next) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Наступна серія',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '${next.season} сезон · ${next.episode} серія',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Автоматичний запуск через $_countdown с',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelNextUp,
                  child: const Text('Скасувати'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _playNext,
                  child: const Text('Дивитись зараз'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}