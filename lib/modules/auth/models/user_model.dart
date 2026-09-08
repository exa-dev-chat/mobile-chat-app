class UserModel {
  final int id;
  final String email;
  final String name;
  final bool isActive;
  final String? avatarUrl;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.isActive = true,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'is_active': isActive,
      'avatar_url': avatarUrl,
      'created_at': createdAt,
    };
  }
}
