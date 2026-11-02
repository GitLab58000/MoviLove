import 'episode_model.dart';

String formatRuntime(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m хв';
  if (m == 0) return '$h г';
  return '$h г $m хв';
}

/// Додаткові дані про фільм/серіал із TMDB
class MediaDetails {
  final List<String> genres;
  final bool isAnime;
  final int? seasons;
  final int? episodes;

  final int? runtime;

  final List<String> directors;

  final List<String> creators;

  final List<String> cast;

  final String? trailerKey;

  final List<SeasonInfo> seasonList;

  const MediaDetails({
    required this.genres,
    required this.isAnime,
    this.seasons,
    this.episodes,
    this.runtime,
    this.directors = const [],
    this.creators = const [],
    this.cast = const [],
    this.trailerKey,
    this.seasonList = const [],
  });

  static int? parseRuntime(Map<String, dynamic> json) {
    int? runtime = json['runtime'] as int?;
    if (runtime == null || runtime == 0) {
      final list = json['episode_run_time'] as List?;
      if (list != null && list.isNotEmpty) runtime = list.first as int?;
    }
    if (runtime == null || runtime == 0) {
      final last = json['last_episode_to_air'];
      if (last is Map) runtime = last['runtime'] as int?;
    }
    return (runtime == null || runtime == 0) ? null : runtime;
  }


  static String? _pickTrailer(Map<String, dynamic> json) {
    final all = ((json['videos']?['results']) as List? ?? [])
        .where((v) => v['site'] == 'YouTube')
        .toList();

    var candidates = all.where((v) => v['type'] == 'Trailer').toList();
    if (candidates.isEmpty) {
      candidates = all.where((v) => v['type'] == 'Teaser').toList();
    }
    if (candidates.isEmpty) return null;

    int score(dynamic v) =>
        (v['iso_639_1'] == 'uk' ? 4 : (v['iso_639_1'] == 'en' ? 2 : 0)) +
            (v['official'] == true ? 1 : 0);
    candidates.sort((a, b) => score(b).compareTo(score(a)));
    return candidates.first['key'] as String?;
  }


  static List<SeasonInfo> _parseSeasons(Map<String, dynamic> json) {
    final list = (json['seasons'] as List? ?? [])
        .map((s) => SeasonInfo(
      number: (s['season_number'] as num?)?.toInt() ?? 0,
      episodeCount: (s['episode_count'] as num?)?.toInt() ?? 0,
    ))
        .where((s) => s.number > 0 && s.episodeCount > 0)
        .toList();
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  factory MediaDetails.fromJson(Map<String, dynamic> json) {
    final genreList = (json['genres'] as List? ?? []);
    final genreIds = genreList.map((g) => g['id']).toSet();

    final crew = ((json['credits']?['crew']) as List? ?? []);
    final cast = ((json['credits']?['cast']) as List? ?? []);

    return MediaDetails(
      genres: genreList.map((g) => g['name'].toString()).toList(),
      isAnime: genreIds.contains(16) && json['original_language'] == 'ja',
      seasons: json['number_of_seasons'] as int?,
      episodes: json['number_of_episodes'] as int?,
      runtime: parseRuntime(json),
      directors: crew
          .where((c) => c['job'] == 'Director')
          .map((c) => c['name'].toString())
          .toSet()
          .toList(),
      creators: (json['created_by'] as List? ?? [])
          .map((c) => c['name'].toString())
          .toList(),
      cast: cast.take(10).map((c) => c['name'].toString()).toList(),
      trailerKey: _pickTrailer(json),
      seasonList: _parseSeasons(json),
    );
  }

  String typeLabel({required bool isTv}) {
    if (isAnime) return 'Аніме';
    return isTv ? 'Серіал' : 'Фільм';
  }
}