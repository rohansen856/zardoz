import 'package:flutter/material.dart';
import '../models/design.dart';
import '../services/api_service.dart';
import '../widgets/design_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _api = ApiService();
  List<Design> _designs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      _designs = await _api.getDesigns();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/logo-square.png', width: 40, height: 40),
                ),
                const SizedBox(width: 12),
                const Text('Designs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    await showSearch(
                      context: context,
                      delegate: _DesignSearch(_api),
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _designs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.design_services, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text('No designs yet',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                                const SizedBox(height: 8),
                                Text('Be the first to share!',
                                    style: TextStyle(color: Colors.grey[400])),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _designs.length,
                              itemBuilder: (context, i) =>
                                  DesignCard(design: _designs[i], onChanged: _load),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _DesignSearch extends SearchDelegate<Design?> {
  final ApiService _api;
  _DesignSearch(this._api);

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    if (query.length < 2) {
      return Center(
        child: Text('Type to search designs...', style: TextStyle(color: Colors.grey[400])),
      );
    }
    return FutureBuilder<List<Design>>(
      future: _api.search(query),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final designs = snap.data ?? [];
        if (designs.isEmpty) {
          return const Center(child: Text('No designs found'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: designs.length,
          itemBuilder: (ctx, i) => DesignCard(design: designs[i]),
        );
      },
    );
  }
}
