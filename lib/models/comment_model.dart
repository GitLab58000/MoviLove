import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String userId;
  final String nickname;
  final String text;
  final int? rating;
  final Timestamp? createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.text,
    required this.rating,
    required this.createdAt,
  });

  factory Comment.fromFirestore(String id, Map<String, dynamic> data) {
    return Comment(
      id: id,
      userId: data['userId'] ?? '',
      nickname: data['nickname'] ?? 'Анонім',
      text: data['text'] ?? '',
      rating: data['rating'],
      createdAt: data['createdAt'],
    );
  }
}