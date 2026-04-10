import 'package:flutter/material.dart';
import '../models/design.dart';
import '../services/api_service.dart';
import '../widgets/design_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _api = ApiService();
  List<Design> _designs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _designs = await _api.getFavorites();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Favorites',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _designs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No favorites yet',
                                style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                            const SizedBox(height: 8),
                            Text('Tap the heart on designs you love',
                                style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _designs.length,
                          itemBuilder: (ctx, i) =>
                              DesignCard(design: _designs[i], onChanged: _load),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
