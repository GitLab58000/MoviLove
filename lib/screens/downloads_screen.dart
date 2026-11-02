import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../services/download_service.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Завантаження'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: DownloadService.changes,
        builder: (context, _, __) {
          return FutureBuilder<List<Movie>>(
            future: DownloadService.list(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final movies = snapshot.data ?? [];
              if (movies.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined,
                            color: Colors.white24, size: 72),
                        SizedBox(height: 16),
                        Text(
                          'Поки немає завантажень.\nВідкрий фільм та нажми значок скачування.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index];
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(movie: movie),
                          ),
                        );
                      },
                      leading: SizedBox(
                        width: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: movie.posterPath != null
                              ? Image.network(
                            movie.fullPosterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white12,
                              child: const Icon(Icons.movie,
                                  color: Colors.white38),
                            ),
                          )
                              : Container(
                            color: Colors.white12,
                            child: const Icon(Icons.movie,
                                color: Colors.white38),
                          ),
                        ),
                      ),
                      title: Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Доступно без інтернету',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white54),
                        onPressed: () async {
                          await DownloadService.delete(movie.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Завантаження видалене')),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}