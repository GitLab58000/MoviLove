import 'package:flutter/material.dart';
import '../models/episode_model.dart';
import '../models/media_details.dart';
import '../models/movie_model.dart';
import '../services/tmdb_service.dart';
import '../services/watch_access.dart';

class EpisodesSection extends StatefulWidget {
  final Movie movie;
  final List<SeasonInfo> seasons;

  const EpisodesSection({
    super.key,
    required this.movie,
    required this.seasons,
  });

  @override
  State<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends State<EpisodesSection> {
  static const int _pageSize = 20;

  late int _season;
  late Future<List<Episode>?> _future;
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    _season = widget.seasons.first.number;
    _load();
  }

  void _load() {
    _future = TmdbService().getSeasonEpisodes(widget.movie, _season);
  }

  void _changeSeason(int season) {
    if (season == _season) return;
    setState(() {
      _season = season;
      _visible = _pageSize;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Серії',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _season,
                  dropdownColor: const Color(0xFF1E1E1E),
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  items: widget.seasons
                      .map((s) => DropdownMenuItem<int>(
                    value: s.number,
                    child: Text('Сезон ${s.number}'),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _changeSeason(value);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Episode>?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              );
            }

            final episodes = snapshot.data;
            if (episodes == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      'Не вдалося завантажити серії',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => setState(_load),
                      child: const Text('Спробувати ще'),
                    ),
                  ],
                ),
              );
            }
            if (episodes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Серій поки немає',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            final shown = episodes.take(_visible).toList();
            return Column(
              children: [
                ...shown.map(
                      (ep) => _EpisodeTile(
                    movie: widget.movie,
                    season: _season,
                    episode: ep,
                  ),
                ),
                if (episodes.length > _visible)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _visible += _pageSize),
                        child: const Text(
                          'Переглянути ще +20',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Movie movie;
  final int season;
  final Episode episode;

  const _EpisodeTile({
    required this.movie,
    required this.season,
    required this.episode,
  });

  Widget _placeholder() {
    return Container(
      width: 120,
      height: 68,
      color: Colors.white12,
      child: const Icon(Icons.movie, color: Colors.white38),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = episode.name.isNotEmpty
        ? episode.name
        : 'Серія ${episode.number}';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => watchMovie(
        context,
        movie,
        season: season,
        episode: episode.number,
        episodeTitle: episode.name.isNotEmpty ? episode.name : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: episode.stillUrl != null
                  ? Image.network(
                episode.stillUrl!,
                width: 120,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.number}. $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (episode.runtime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatRuntime(episode.runtime!),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (episode.overview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        episode.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.play_circle_outline, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}