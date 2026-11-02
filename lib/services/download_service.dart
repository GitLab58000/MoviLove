import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/movie_model.dart';

// Установка відео на пристрій, працює без інтернету
class DownloadService {
  // 1 відео на всі плеєри
  static const String demoVideoUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4';

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> videoFile(int movieId) async =>
      File('${(await _dir()).path}/$movieId.mp4');

  static Future<File> _metaFile(int movieId) async =>
      File('${(await _dir()).path}/$movieId.json');

  static Future<bool> isDownloaded(int movieId) async =>
      (await videoFile(movieId)).exists();

  // Скачування
  static Future<void> download(
      Movie movie,
      void Function(double progress) onProgress,
      ) async {
    final client = http.Client();
    final dir = await _dir();
    final part = File('${dir.path}/${movie.id}.part');

    try {
      final response = await client.send(
        http.Request('GET', Uri.parse(demoVideoUrl)),
      );
      if (response.statusCode != 200) {
        throw Exception('Сервер відповів ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }

      await part.rename((await videoFile(movie.id)).path);
      await (await _metaFile(movie.id)).writeAsString(jsonEncode({
        'id': movie.id,
        'title': movie.title,
        'overview': movie.overview,
        'posterPath': movie.posterPath,
        'voteAverage': movie.voteAverage,
        'releaseDate': movie.releaseDate,
      }));
      changes.value++;
    } catch (e) {
      if (await part.exists()) await part.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> delete(int movieId) async {
    final video = await videoFile(movieId);
    final meta = await _metaFile(movieId);
    if (await video.exists()) await video.delete();
    if (await meta.exists()) await meta.delete();
    changes.value++;
  }

  // Список скачаного
  static Future<List<Movie>> list() async {
    final dir = await _dir();
    final entries = <MapEntry<DateTime, Movie>>[];

    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final data = jsonDecode(await entity.readAsString());
        final id = data['id'] as int;
        if (!await isDownloaded(id)) continue;
        entries.add(MapEntry(
          await entity.lastModified(),
          Movie(
            id: id,
            title: data['title'] ?? '',
            overview: data['overview'] ?? '',
            posterPath: data['posterPath'],
            voteAverage: (data['voteAverage'] ?? 0).toDouble(),
            releaseDate: data['releaseDate'],
          ),
        ));
      } catch (_) {

      }
    }

    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries.map((e) => e.value).toList();
  }
}