import 'dart:async';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';
import '../widgets/continue_watching_section.dart';
import '../models/genres.dart';
import '../models/media_details.dart';
import '../widgets/genre_filter_panel.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TmdbService _tmdbService = TmdbService();

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  CatalogFilter _filter = const CatalogFilter(ContentType.movie, {});

  List<Movie> _movies = [];
  int _page = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await _tmdbService.searchMovies(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _showSuggestions = true;
        });
      }
    });
  }

  void _applyFilter(CatalogFilter filter) {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _filter = filter;
      _showSuggestions = false;
      _searchResults = [];
      _movies = [];
      _page = 1;
      _totalPages = 1;
      _error = null;
      _isLoading = true;
      _isLoadingMore = false;
    });
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final filter = _filter;
    try {
      final result = await _tmdbService.discover(filter.type, filter.genres);

      if (!mounted || filter != _filter) return;
      setState(() {
        _movies = result.movies;
        _totalPages = result.totalPages;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || filter != _filter) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _page >= _totalPages) return;
    setState(() => _isLoadingMore = true);
    final filter = _filter;
    try {
      final result = await _tmdbService.discover(
        filter.type,
        filter.genres,
        page: _page + 1,
      );
      if (!mounted || filter != _filter) return;

      final existing = _movies.map((m) => m.docId).toSet();
      setState(() {
        _movies = [
          ..._movies,
          ...result.movies.where((m) => !existing.contains(m.docId)),
        ];
        _page += 1;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося завантажити ще: $e')),
      );
    }
  }

  String get _filterTitle {
    final type = _filter.type;
    if (type == ContentType.anime) return 'Аніме: популярне';
    if (_filter.genres.isEmpty) return '${type.label}: популярне';
    final names = type == ContentType.tv ? tvGenres : movieGenres;
    final selected = names.entries
        .where((e) => _filter.genres.contains(e.key))
        .map((e) => e.value)
        .join(', ');
    return '${type.label}: $selected';
  }

  Widget _buildCatalog() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Помилка: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _loadFirstPage();
                },
                child: const Text('Спробувати ще'),
              ),
            ],
          ),
        ),
      );
    }

    final movies = _movies;
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: ContinueWatchingSection()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Text(
              _filterTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (movies.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Нічого не знайдено',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _MovieCard(movie: movies[index]),
                childCount: movies.length,
              ),
            ),
          ),
        if (movies.isNotEmpty && _page < _totalPages)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoadingMore ? null : _loadMore,
                child: _isLoadingMore
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.redAccent,
                  ),
                )
                    : const Text(
                  'Переглянути ще +20',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final result = await showGeneralDialog<CatalogFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Фільтри',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) => GenreFilterPanel(initial: _filter),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
    if (result != null && mounted) _applyFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Пошук...',
            hintStyle: const TextStyle(color: Colors.white38),

            filled: true,
            fillColor: const Color(0xFF2A2A2A),

            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),

            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _showSuggestions = false;
                        _searchResults = [];
                      });
                    },
                  ),
                IconButton(
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: _filter.isActive,
                    smallSize: 8,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.tune, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildCatalog(),

          // Підсказки поверх каталога
          if (_showSuggestions)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xFF121212),
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? const Center(
                  child: Text(
                    'Нічого не знайдено',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final movie = _searchResults[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: movie.posterPath != null
                            ? Image.network(
                          movie.fullPosterUrl,
                          width: 46,
                          height: 66,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(
                                width: 46,
                                height: 66,
                                color: Colors.white12,
                              ),
                        )
                            : Container(
                          width: 46,
                          height: 66,
                          color: Colors.white12,
                        ),
                      ),
                      title: Text(
                        movie.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() => _showSuggestions = false);
                        _searchController.clear();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MovieDetailsScreen(movie: movie),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;

  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: movie.posterPath != null
                  ? Image.network(
                movie.fullPosterUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white12,
                  child: const Icon(Icons.broken_image,
                      color: Colors.white38),
                ),
              )
                  : Container(
                color: Colors.white12,
                child:
                const Icon(Icons.movie, color: Colors.white38),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                movie.voteAverage.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Flexible(
                child: FutureBuilder<int?>(
                  future: TmdbService().getRuntime(movie),
                  builder: (context, snapshot) {
                    final minutes = snapshot.data;
                    if (minutes == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule,
                              color: Colors.white38, size: 13),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              formatRuntime(minutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}