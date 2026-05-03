class User {
  final int id;
  final String name;
  final String username;
  final String createdAt;
  final int? designCount;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.createdAt,
    this.designCount,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        username: json['username'],
        createdAt: json['created_at'] ?? '',
        designCount: json['design_count'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'created_at': createdAt,
        if (designCount != null) 'design_count': designCount,
      };
}
