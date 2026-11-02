import 'package:flutter/material.dart';
import '../models/genres.dart';

class GenreFilterPanel extends StatefulWidget {
  final CatalogFilter initial;

  const GenreFilterPanel({super.key, required this.initial});

  @override
  State<GenreFilterPanel> createState() => _GenreFilterPanelState();
}

class _GenreFilterPanelState extends State<GenreFilterPanel> {
  late ContentType _type;
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _selected = {...widget.initial.genres};
  }

  Map<int, String> get _genres =>
      _type == ContentType.tv ? tvGenres : movieGenres;

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = _type == ContentType.movie && _selected.isEmpty;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Фільтри',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(
                            CatalogFilter(ContentType.movie, <int>{}),
                          ),
                          child: const Text(
                            'Скинути',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Тип'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ContentType.values.map((type) {
                                return ChoiceChip(
                                  label: Text(type.label),
                                  selected: _type == type,
                                  showCheckmark: false,
                                  selectedColor: Colors.redAccent,
                                  backgroundColor: Colors.white10,
                                  side: BorderSide.none,
                                  labelStyle:
                                  const TextStyle(color: Colors.white),
                                  onSelected: (_) {
                                    setState(() {
                                      if (_type != type) {
                                        _type = type;
                                        _selected.clear();
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            if (_type == ContentType.anime)
                              const Text(
                                'Для аніме показуємо популярні японські серіали, жанри не потрібні.',
                                style: TextStyle(color: Colors.white54),
                              )
                            else ...[
                              _sectionTitle('Жанри'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _genres.entries.map((genre) {
                                  return FilterChip(
                                    label: Text(genre.value),
                                    selected: _selected.contains(genre.key),
                                    showCheckmark: true,
                                    checkmarkColor: Colors.white,
                                    selectedColor: Colors.redAccent,
                                    backgroundColor: Colors.white10,
                                    side: BorderSide.none,
                                    labelStyle:
                                    const TextStyle(color: Colors.white),
                                    onSelected: (value) {
                                      setState(() {
                                        if (value) {
                                          _selected.add(genre.key);
                                        } else {
                                          _selected.remove(genre.key);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context)
                            .pop(CatalogFilter(_type, _selected)),
                        child: Text(
                          isDefault
                              ? 'Показати всі'
                              : _selected.isEmpty
                              ? 'Застосувати'
                              : 'Застосувати (${_selected.length})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}