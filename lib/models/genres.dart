enum ContentType {
  movie('Фільми'),
  tv('Серіали'),
  anime('Аніме');

  final String label;
  const ContentType(this.label);
}

class CatalogFilter {
  final ContentType type;
  final Set<int> genres;

  const CatalogFilter(this.type, this.genres);

  bool get isActive => type != ContentType.movie || genres.isNotEmpty;
}

const Map<int, String> movieGenres = {
  28: 'Бойовик',
  12: 'Пригоди',
  16: 'Мультфільм',
  35: 'Комедія',
  80: 'Кримінал',
  99: 'Документальний',
  18: 'Драма',
  10751: 'Сімейний',
  14: 'Фентезі',
  36: 'Історичний',
  27: 'Жахи',
  10402: 'Музика',
  9648: 'Детектив',
  10749: 'Мелодрама',
  878: 'Фантастика',
  53: 'Трилер',
  10752: 'Військовий',
  37: 'Вестерн',
};

const Map<int, String> tvGenres = {
  10759: 'Бойовик і пригоди',
  16: 'Мультфільм',
  35: 'Комедія',
  80: 'Кримінал',
  99: 'Документальний',
  18: 'Драма',
  10751: 'Сімейний',
  9648: 'Детектив',
  10765: 'Фантастика і фентезі',
  10768: 'Війна і політика',
  37: 'Вестерн',
  10764: 'Реаліті-шоу',
};