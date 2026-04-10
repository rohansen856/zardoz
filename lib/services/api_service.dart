import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/design.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  int? _userId;
  void setUserId(int? id) => _userId = id;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_userId != null) 'X-User-Id': _userId.toString(),
      };

  // ---- Auth ----

  Future<User> login(String name, String username) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'username': username}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final user = User.fromJson(jsonDecode(res.body));
      _userId = user.id;
      return user;
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Login failed');
  }

  // ---- Designs ----

  Future<List<Design>> getDesigns({int page = 1, int limit = 20}) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/designs?page=$page&limit=$limit'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((d) => Design.fromJson(d)).toList();
    }
    throw Exception('Failed to load designs');
  }

  Future<Design> getDesign(int id) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/designs/$id'),
      headers: _headers,
    );
    if (res.statusCode == 200) return Design.fromJson(jsonDecode(res.body));
    throw Exception('Design not found');
  }

  Future<void> createDesign({
    required String title,
    required String description,
    required String imageBase64,
    String tags = '',
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/designs'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'image': imageBase64,
        'tags': tags,
      }),
    );
    if (res.statusCode == 201) return;
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Upload failed');
  }

  Future<void> deleteDesign(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/designs/$id'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Delete failed');
  }

  // ---- Favorites ----

  Future<bool> toggleFavorite(int designId) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/designs/$designId/favorite'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['favorited'];
    throw Exception('Failed');
  }

  Future<List<Design>> getFavorites() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((d) => Design.fromJson(d)).toList();
    }
    throw Exception('Failed to load favorites');
  }

  // ---- Saved ----

  Future<bool> toggleSave(int designId) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/designs/$designId/save'),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['saved'];
    throw Exception('Failed');
  }

  Future<List<Design>> getSaved() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/saved'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((d) => Design.fromJson(d)).toList();
    }
    throw Exception('Failed to load saved');
  }

  // ---- Users ----

  Future<User> getUser(int id) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$id'),
      headers: _headers,
    );
    if (res.statusCode == 200) return User.fromJson(jsonDecode(res.body));
    throw Exception('User not found');
  }

  Future<List<Design>> getUserDesigns(int userId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/designs'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((d) => Design.fromJson(d)).toList();
    }
    throw Exception('Failed');
  }

  // ---- Search ----

  Future<List<Design>> search(String query) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((d) => Design.fromJson(d)).toList();
    }
    throw Exception('Search failed');
  }
}
