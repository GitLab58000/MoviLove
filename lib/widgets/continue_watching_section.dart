import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie_model.dart';
import '../services/watch_access.dart';

class ContinueWatchingSection extends StatelessWidget {
  const ContinueWatchingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('updatedAt', descending: true)
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Text(
                'Нещодавно переглянуто',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final movie = Movie.fromFirestore(data);
                  final positionMs = (data['positionMs'] ?? 0) as num;
                  final durationMs = (data['durationMs'] ?? 0) as num;
                  final progress = durationMs > 0
                      ? (positionMs / durationMs).clamp(0.0, 1.0).toDouble()
                      : 0.0;

                  final season = (data['season'] as num?)?.toInt();
                  final episode = (data['episode'] as num?)?.toInt();
                  final episodeTitle = data['episodeTitle'] as String?;

                  return GestureDetector(
                    onTap: () => watchMovie(
                      context,
                      movie,
                      season: season,
                      episode: episode,
                      episodeTitle: episodeTitle,
                    ),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: movie.posterPath != null
                                        ? Image.network(
                                      movie.fullPosterUrl,
                                      fit: BoxFit.cover,
                                    )
                                        : Container(color: Colors.white12),
                                  ),
                                ),
                                const Positioned.fill(
                                  child: Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white70,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                if (progress > 0)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(8),
                                      ),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 4,
                                        color: Colors.redAccent,
                                        backgroundColor: Colors.black54,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            movie.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          if (movie.isTv && season != null && episode != null)
                            Text(
                              '$season сезон · $episode серія',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}