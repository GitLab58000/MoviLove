import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import '../widgets/guest_prompt.dart';

class CommentsSection extends StatefulWidget {
  final String movieId;

  const CommentsSection({super.key, required this.movieId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _textController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmitting = false;

  DocumentReference<Map<String, dynamic>> get _movieDocRef =>
      FirebaseFirestore.instance
          .collection('movies')
          .doc(widget.movieId);

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _movieDocRef.collection('comments');

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showLoginSnackBar(context, 'Увійдіть в акаунт, щоб залишити коментар');
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final nickname = userDoc.data()?['nickname'] ?? 'Анонім';

      await _commentsRef.add({
        'userId': user.uid,
        'nickname': nickname,
        'text': text,
        'rating': _selectedRating == 0 ? null : _selectedRating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_selectedRating > 0) {
        await _updateAverageRating();
      }

      _textController.clear();
      setState(() => _selectedRating = 0);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateAverageRating() async {
    final ratedComments =
    await _commentsRef.where('rating', isNull: false).get();

    final ratings = ratedComments.docs
        .map((doc) => (doc.data()['rating'] as num).toDouble())
        .toList();

    if (ratings.isEmpty) {
      await _movieDocRef.set({
        'avgRating': 0.0,
        'ratingsCount': 0,
      }, SetOptions(merge: true));
      return;
    }

    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    await _movieDocRef.set({
      'avgRating': avg,
      'ratingsCount': ratings.length,
    }, SetOptions(merge: true));
  }

  Future<void> _deleteComment(String commentId, bool hadRating) async {
    await _commentsRef.doc(commentId).delete();
    if (hadRating) {
      await _updateAverageRating();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _movieDocRef.snapshots(),
      builder: (context, movieSnapshot) {
        final movieData = movieSnapshot.data?.data();
        final avgRating = (movieData?['avgRating'] as num?)?.toDouble() ?? 0.0;
        final ratingsCount = (movieData?['ratingsCount'] as num?)?.toInt() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Коментарі',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($ratingsCount) MoviLove',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _selectedRating =
                            _selectedRating == starIndex ? 0 : starIndex;
                          });
                        },
                        icon: Icon(
                          starIndex <= _selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 26,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Залиште коментар...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: _isSubmitting ? null : _submitComment,
                      child: _isSubmitting
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('Відправити',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _commentsRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Поки немає коментарів. Будьте першим!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white12),
                  itemBuilder: (context, index) {
                    final comment = Comment.fromFirestore(
                        docs[index].id, docs[index].data());

                    final isOwnComment = comment.userId ==
                        FirebaseAuth.instance.currentUser?.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comment.nickname,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (comment.rating != null) ...[
                                const SizedBox(width: 8),
                                Row(
                                  children: List.generate(
                                    5,
                                        (i) => Icon(
                                      i < comment.rating!
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                              if (isOwnComment) ...[
                                const Spacer(),
                                InkWell(
                                  onTap: () => _deleteComment(
                                    comment.id,
                                    comment.rating != null,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.text,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}