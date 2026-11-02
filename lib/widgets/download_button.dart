import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../services/download_service.dart';
import '../services/watch_access.dart';

class DownloadButton extends StatefulWidget {
  final Movie movie;

  const DownloadButton({super.key, required this.movie});

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool _downloaded = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final downloaded = await DownloadService.isDownloaded(widget.movie.id);
    if (!mounted) return;
    setState(() => _downloaded = downloaded);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onPressed() async {
    if (_progress != null) return;

    if (_downloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Видалити завантаження?'),
          content: Text('«${widget.movie.title}» буде видалений з памяті телефону.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Відміна'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Видалити'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await DownloadService.delete(widget.movie.id);
      if (!mounted) return;
      setState(() => _downloaded = false);
      _showMessage('Завантаження видалене');
      return;
    }

    if (!await ensureSubscribed(context)) return;

    setState(() => _progress = 0);
    try {
      await DownloadService.download(widget.movie, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _downloaded = true;
        _progress = null;
      });
      _showMessage('Скачано. Дивитись можна у вкладці «Завантаження»');
    } catch (e) {
      if (!mounted) return;
      setState(() => _progress = null);
      _showMessage('Не вдалося скачати: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    if (_progress != null) {
      icon = SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          value: _progress == 0 ? null : _progress,
          strokeWidth: 3,
          color: Colors.redAccent,
        ),
      );
    } else if (_downloaded) {
      icon = const Icon(Icons.download_done, color: Colors.redAccent, size: 28);
    } else {
      icon = const Icon(Icons.download_outlined, color: Colors.white, size: 28);
    }

    return IconButton(
      onPressed: _progress != null ? null : _onPressed,
      icon: icon,
      tooltip: _downloaded ? 'Видалити завантаження' : 'Скачати',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white12,
        padding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}