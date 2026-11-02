import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie_model.dart';
import '../models/media_details.dart';
import '../services/tmdb_service.dart';
import '../widgets/comments_section.dart';
import 'player_screen.dart';
import '../services/watch_access.dart';
import '../widgets/download_button.dart';
import '../widgets/guest_prompt.dart';
import '../widgets/episodes_section.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  late Future<MediaDetails?> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = TmdbService().getDetails(widget.movie);
    _checkIfFavorite();
  }

  DocumentReference<Map<String, dynamic>>? get _favoriteDocRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.movie.docId);
  }

  Future<void> _checkIfFavorite() async {
    final ref = _favoriteDocRef;
    if (ref == null) {
      setState(() => _isLoadingFavorite = false);
      return;
    }
    final doc = await ref.get();
    setState(() {
      _isFavorite = doc.exists;
      _isLoadingFavorite = false;
    });
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showLoginSnackBar(context, 'Увійдіть в акаунт, щоб добавляти в обране');
      return;
    }

    final ref = _favoriteDocRef!;
    if (_isFavorite) {
      await ref.delete();
    } else {
      await ref.set({
        'movieId': widget.movie.id,
        'mediaType': widget.movie.mediaType,
        'title': widget.movie.title,
        'overview': widget.movie.overview,
        'posterPath': widget.movie.posterPath,
        'voteAverage': widget.movie.voteAverage,
        'releaseDate': widget.movie.releaseDate,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    setState(() => _isFavorite = !_isFavorite);
  }
  Future<void> _onWatchPressed() async {
    if (!widget.movie.isTv) {
      await watchMovie(context, widget.movie);
      return;
    }

    final details = await _detailsFuture;
    if (!mounted) return;
    final season = (details != null && details.seasonList.isNotEmpty)
        ? details.seasonList.first.number
        : 1;
    await watchMovie(context, widget.movie, season: season, episode: 1);
  }

  Future<void> _openTrailer(String key) async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=$key'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося відкрити трейлер')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити трейлер')),
      );
    }
  }

  /// "Режисер: " або "Актори: "
  Widget _creditLine(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
      style: const TextStyle(height: 1.5),
    );
  }

  String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
            flexibleSpace: FlexibleSpaceBar(
              background: movie.posterPath != null
                  ? Image.network(
                movie.fullPosterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white12,
                  child: const Icon(Icons.broken_image,
                      color: Colors.white38, size: 60),
                ),
              )
                  : Container(
                color: Colors.white12,
                child: const Icon(Icons.movie,
                    color: Colors.white38, size: 60),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<MediaDetails?>(
                    future: _detailsFuture,
                    builder: (context, snapshot) {
                      final details = snapshot.data;
                      final year = (movie.releaseDate != null &&
                          movie.releaseDate!.length >= 4)
                          ? movie.releaseDate!.substring(0, 4)
                          : null;
                      // Рік, Тип, Жанри
                      final info = [
                        if (year != null) year,
                        details != null
                            ? details.typeLabel(isTv: movie.isTv)
                            : (movie.isTv ? 'Серіал' : 'Фільм'),
                        if (details != null && details.genres.isNotEmpty)
                          details.genres.join(', '),
                      ].join(' · ');
                      final seasons = details?.seasons ?? 0;
                      final episodes = details?.episodes ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    movie.voteAverage.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'TMDB',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                              if (details?.runtime != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule,
                                        color: Colors.white54, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      movie.isTv
                                          ? '${formatRuntime(details!.runtime!)} / серія'
                                          : formatRuntime(details!.runtime!),
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                  ],
                                ),
                              Text(
                                info,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          if (movie.isTv && seasons > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.video_library_outlined,
                                    color: Colors.white54, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '$seasons ${_plural(seasons, 'сезон', 'сезони', 'сезонів')}'
                                      '${episodes > 0 ? ' · $episodes ${_plural(episodes, 'серія', 'серії', 'серій')}' : ''}',
                                  style:
                                  const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _onWatchPressed,
                          icon: const Icon(Icons.play_arrow,
                              color: Colors.white),
                          label: const Text(
                            'Дивитись',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _isLoadingFavorite ? null : _toggleFavorite,
                        icon: Icon(
                          _isFavorite
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          color: _isFavorite
                              ? Colors.redAccent
                              : Colors.white,
                          size: 28,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white12,
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (!movie.isTv) ...[
                        const SizedBox(width: 12),
                        DownloadButton(movie: widget.movie),
                      ],
                    ],
                  ),
                  FutureBuilder<MediaDetails?>(
                    future: _detailsFuture,
                    builder: (context, snapshot) {
                      final key = snapshot.data?.trailerKey;
                      if (key == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _openTrailer(key),
                            icon: const Icon(Icons.ondemand_video,
                                size: 18, color: Colors.white70),
                            label: const Text(
                              'Трейлер',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Опис',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.overview.isNotEmpty
                        ? movie.overview
                        : 'Опис відсутній.',
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  FutureBuilder<MediaDetails?>(
                    future: _detailsFuture,
                    builder: (context, snapshot) {
                      final details = snapshot.data;
                      if (details == null) return const SizedBox.shrink();
                      final people =
                      movie.isTv ? details.creators : details.directors;
                      final peopleLabel = movie.isTv
                          ? (people.length > 1 ? 'Творці' : 'Творець')
                          : (people.length > 1 ? 'Режисери' : 'Режисер');
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (people.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _creditLine(peopleLabel, people.join(', ')),
                          ],
                          if (details.cast.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _creditLine('Актори', details.cast.join(', ')),
                          ],
                        ],
                      );
                    },
                  ),
                  if (movie.isTv)
                    FutureBuilder<MediaDetails?>(
                      future: _detailsFuture,
                      builder: (context, snapshot) {
                        final seasons = snapshot.data?.seasonList ?? [];
                        if (seasons.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: EpisodesSection(
                            movie: movie,
                            seasons: seasons,
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                  CommentsSection(movieId: movie.docId),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}