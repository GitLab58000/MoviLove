import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie_model.dart';
import '../screens/player_screen.dart';
import '../screens/subscription_screen.dart';
import '../widgets/guest_prompt.dart';

// Перевіряє вхід і підписку
Future<bool> ensureSubscribed(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    showLoginSnackBar(context, 'Увійдіть в акаунт, щоб продовжити');
    return false;
  }

  final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
  var subscribed = false;
  try {
    final doc = await ref.get().timeout(const Duration(seconds: 3));
    subscribed = doc.data()?['isSubscribed'] == true;
  } catch (_) {

    try {
      final doc = await ref.get(const GetOptions(source: Source.cache));
      subscribed = doc.data()?['isSubscribed'] == true;
    } catch (_) {}
  }

  if (!context.mounted) return false;
  if (subscribed) return true;

  final paid = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
  );
  return paid == true;
}

Future<void> watchMovie(
    BuildContext context,
    Movie movie, {
      int? season,
      int? episode,
      String? episodeTitle,
    }) async {
  if (!await ensureSubscribed(context)) return;
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerScreen(
        movie: movie,
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
      ),
    ),
  );
}