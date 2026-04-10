import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/design.dart';
import '../services/api_service.dart';

class DesignDetailScreen extends StatefulWidget {
  final int designId;
  const DesignDetailScreen({super.key, required this.designId});

  @override
  State<DesignDetailScreen> createState() => _DesignDetailScreenState();
}

class _DesignDetailScreenState extends State<DesignDetailScreen> {
  final _api = ApiService();
  Design? _design;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _design = await _api.getDesign(widget.designId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_design == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Design not found')),
      );
    }

    final d = _design!;
    final imageUrl = d.imageUrl;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(d.isFavorited ? Icons.favorite : Icons.favorite_outline,
                    color: d.isFavorited ? Colors.red : Colors.white),
                onPressed: () async {
                  final res = await _api.toggleFavorite(d.id);
                  setState(() => d.isFavorited = res);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'design_${d.id}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.title,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          d.authorName.isNotEmpty ? d.authorName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.authorName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('@${d.authorUsername}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                  if (d.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(d.description,
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[700], height: 1.5)),
                  ],
                  if (d.tagList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: d.tagList
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('#$tag',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600])),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await _api.toggleFavorite(d.id);
                            setState(() => d.isFavorited = res);
                          },
                          icon: Icon(
                            d.isFavorited ? Icons.favorite : Icons.favorite_outline,
                            color: d.isFavorited ? Colors.red : null,
                            size: 20,
                          ),
                          label: Text(d.isFavorited ? 'Favorited' : 'Favorite'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await _api.toggleSave(d.id);
                            setState(() => d.isSaved = res);
                          },
                          icon: Icon(
                            d.isSaved ? Icons.bookmark : Icons.bookmark_outline,
                            size: 20,
                          ),
                          label: Text(d.isSaved ? 'Saved' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Project button — the key feature
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/project', arguments: {
                          'imageUrl': imageUrl,
                          'title': d.title,
                        });
                      },
                      icon: const Icon(Icons.cast, size: 22),
                      label: const Text('Project onto Fabric'),
                      style: ElevatedButton.styleFrom(
                        textStyle: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Connect a projector and project this design onto fabric',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
