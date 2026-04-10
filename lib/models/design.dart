class Design {
  final int id;
  final int userId;
  final String title;
  final String description;
  final String imageUrl;
  final String tags;
  final String createdAt;
  final String authorName;
  final String authorUsername;
  bool isFavorited;
  bool isSaved;

  Design({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.imageUrl,
    this.tags = '',
    required this.createdAt,
    required this.authorName,
    required this.authorUsername,
    this.isFavorited = false,
    this.isSaved = false,
  });

  factory Design.fromJson(Map<String, dynamic> json) => Design(
        id: json['id'],
        userId: json['user_id'],
        title: json['title'],
        description: json['description'] ?? '',
        imageUrl: json['image_url'] ?? json['image_filename'] ?? '',
        tags: json['tags'] ?? '',
        createdAt: json['created_at'] ?? '',
        authorName: json['author_name'] ?? '',
        authorUsername: json['author_username'] ?? '',
        isFavorited: json['is_favorited'] ?? false,
        isSaved: json['is_saved'] ?? false,
      );

  List<String> get tagList => tags.isNotEmpty
      ? tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
      : [];
}
