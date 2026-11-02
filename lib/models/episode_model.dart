/// Сезон серіалу
class SeasonInfo {
  final int number;
  final int episodeCount;

  const SeasonInfo({required this.number, required this.episodeCount});
}

/// Одна серія
class Episode {
  final int number;
  final String name;
  final String overview;
  final String? stillPath;

  final int? runtime;

  const Episode({
    required this.number,
    required this.name,
    required this.overview,
    required this.stillPath,
    required this.runtime,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    final runtime = (json['runtime'] as num?)?.toInt();
    return Episode(
      number: (json['episode_number'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      overview: (json['overview'] as String?)?.trim() ?? '',
      stillPath: json['still_path'] as String?,
      runtime: (runtime == null || runtime == 0) ? null : runtime,
    );
  }

  String? get stillUrl => stillPath != null
      ? 'https://image.tmdb.org/t/p/w300$stillPath'
      : null;
}