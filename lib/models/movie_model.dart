class Movie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final double voteAverage;
  final String? releaseDate;

  final String mediaType;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.voteAverage,
    required this.releaseDate,
    this.mediaType = 'movie',
  });

  factory Movie.fromJson(Map<String, dynamic> json, {String? mediaType}) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? json['name'] ?? 'Без назви',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      releaseDate: json['release_date'] ?? json['first_air_date'],
      mediaType: mediaType ?? (json['media_type'] == 'tv' ? 'tv' : 'movie'),
    );
  }

  factory Movie.fromFirestore(Map<String, dynamic> data) {
    return Movie(
      id: data['movieId'],
      title: data['title'] ?? '',
      overview: data['overview'] ?? '',
      posterPath: data['posterPath'],
      voteAverage: (data['voteAverage'] ?? 0).toDouble(),
      releaseDate: data['releaseDate'],
      mediaType: data['mediaType'] ?? 'movie',
    );
  }

  bool get isTv => mediaType == 'tv';

  String get docId => isTv ? 'tv_$id' : '$id';

  String get fullPosterUrl =>
      posterPath != null
          ? 'https://image.tmdb.org/t/p/w500$posterPath'
          : '';
}