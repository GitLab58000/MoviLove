import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/genres.dart';
import '../models/media_details.dart';
import '../models/movie_model.dart';
import '../models/episode_model.dart';
import '../secrets.dart';

class MoviePage {
  final List<Movie> movies;
  final int totalPages;

  const MoviePage(this.movies, this.totalPages);
}

class TmdbService {
  static const String _apiKey = Secrets.tmdbApiKey;
  static const String _host = 'api.themoviedb.org';

  Future<MoviePage> _fetchPage(Uri url, String mediaType) async {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      final movies = results
          .map((json) => Movie.fromJson(json, mediaType: mediaType))
          .toList();
      return MoviePage(movies, (data['total_pages'] ?? 1) as int);
    } else {
      throw Exception('Помилка завантаження: ${response.statusCode}');
    }
  }

  Future<MoviePage> getPopularMovies({int page = 1}) {
    final url = Uri.https(_host, '/3/movie/popular', {
      'api_key': _apiKey,
      'language': 'uk-UA',
      'page': '$page',
    });
    return _fetchPage(url, 'movie');
  }

  Future<MoviePage> getPopularSeries({int page = 1}) {
    final url = Uri.https(_host, '/3/tv/popular', {
      'api_key': _apiKey,
      'language': 'uk-UA',
      'page': '$page',
    });
    return _fetchPage(url, 'tv');
  }

  // Каталог за вибраним типом і жанрами
  // Якщо без жанрів, тоді показ популярного
  Future<MoviePage> discover(
      ContentType type,
      Set<int> genres, {
        int page = 1,
      }) {
    switch (type) {
      case ContentType.movie:
        if (genres.isEmpty) return getPopularMovies(page: page);
        return _fetchPage(
          Uri.https(_host, '/3/discover/movie', {
            'api_key': _apiKey,
            'language': 'uk-UA',
            'sort_by': 'popularity.desc',
            'include_adult': 'false',
            'vote_count.gte': '50',
            'with_genres': genres.join('|'),
            'page': '$page',
          }),
          'movie',
        );
      case ContentType.tv:
        if (genres.isEmpty) return getPopularSeries(page: page);
        return _fetchPage(
          Uri.https(_host, '/3/discover/tv', {
            'api_key': _apiKey,
            'language': 'uk-UA',
            'sort_by': 'popularity.desc',
            'include_adult': 'false',
            'vote_count.gte': '20',
            'with_genres': genres.join('|'),
            'page': '$page',
          }),
          'tv',
        );
      case ContentType.anime:
        return _fetchPage(
          Uri.https(_host, '/3/discover/tv', {
            'api_key': _apiKey,
            'language': 'uk-UA',
            'sort_by': 'popularity.desc',
            'include_adult': 'false',
            'vote_count.gte': '20',
            'with_genres': '16',
            'with_original_language': 'ja',
            'page': '$page',
          }),
          'tv',
        );
    }
  }

  // Кеш пам'яті карток
  static final Map<String, Future<MediaDetails?>> _detailsCache = {};
  static final Map<String, Future<int?>> _runtimeCache = {};

  String _detailsPath(Movie movie) =>
      movie.isTv ? '/3/tv/${movie.id}' : '/3/movie/${movie.id}';

  // Повні дані для екрана фільму: жанри, сезони, акторський склад, трейлер
  Future<MediaDetails?> getDetails(Movie movie) {
    return _detailsCache.putIfAbsent(movie.docId, () async {
      try {
        final response = await http.get(Uri.https(_host, _detailsPath(movie), {
          'api_key': _apiKey,
          'language': 'uk-UA',
          'append_to_response': 'credits,videos',
          'include_video_language': 'uk,en,null',
        }));
        if (response.statusCode == 200) {
          return MediaDetails.fromJson(json.decode(response.body));
        }
      } catch (_) {}
      _detailsCache.remove(movie.docId);
      return null;
    });
  }

  Future<int?> getRuntime(Movie movie) {
    return _runtimeCache.putIfAbsent(movie.docId, () async {
      try {
        final response = await http.get(Uri.https(_host, _detailsPath(movie), {
          'api_key': _apiKey,
          'language': 'uk-UA',
        }));
        if (response.statusCode == 200) {
          return MediaDetails.parseRuntime(json.decode(response.body));
        }
      } catch (_) {}
      _runtimeCache.remove(movie.docId);
      return null;
    });
  }
  static final Map<String, Future<List<Episode>?>> _episodesCache = {};


  Future<List<Episode>?> getSeasonEpisodes(Movie movie, int season) {
    final key = '${movie.id}_$season';
    return _episodesCache.putIfAbsent(key, () async {
      try {
        final response = await http.get(Uri.https(
          _host,
          '/3/tv/${movie.id}/season/$season',
          {'api_key': _apiKey, 'language': 'uk-UA'},
        ));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final list = (data['episodes'] as List? ?? []);
          return list
              .map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
      _episodesCache.remove(key);
      return null;
    });
  }
  // Пошук і по фільмах, і по серіалах
  Future<List<Movie>> searchMovies(String query) async {
    if (query.trim().isEmpty) return [];
    final url = Uri.https(_host, '/3/search/multi', {
      'api_key': _apiKey,
      'language': 'uk-UA',
      'query': query,
      'include_adult': 'false',
    });
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results
          .where((j) => j['media_type'] == 'movie' || j['media_type'] == 'tv')
          .map((j) => Movie.fromJson(j))
          .toList();
    }
    return [];
  }
}