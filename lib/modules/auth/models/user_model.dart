class UserModel {
  final int id;
  final String email;
  final String name;
  final bool isActive;
  final String? avatarUrl;
  final String? createdAt;
  final String? appleId;
  final String? googleId;
  final bool isEmailVerified;
  final bool isGoogleLinked;
  final bool isAppleLinked;
  final bool hasPassword;
  final bool needsOnboarding;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.isActive = true,
    this.avatarUrl,
    this.createdAt,
    this.appleId,
    this.googleId,
    this.isEmailVerified = false,
    this.isGoogleLinked = false,
    this.isAppleLinked = false,
    this.hasPassword = false,
    this.needsOnboarding = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['user_id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
    final appleId = json['apple_id'] as String?;
    final googleId = json['google_id'] as String?;

    final isGoogle = json['is_google_linked'] as bool? ?? (googleId != null && googleId.isNotEmpty);
    final isApple = json['is_apple_linked'] as bool? ?? (appleId != null && appleId.isNotEmpty);

    return UserModel(
      id: id,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      createdAt: json['created_at']?.toString() ?? json['last_seen']?.toString(),
      appleId: appleId,
      googleId: googleId,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isGoogleLinked: isGoogle,
      isAppleLinked: isApple,
      hasPassword: json['has_password'] as bool? ?? false,
      needsOnboarding: json['needs_onboarding'] as bool? ?? (isApple && !isGoogle),
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
      'apple_id': appleId,
      'google_id': googleId,
      'is_email_verified': isEmailVerified,
      'is_google_linked': isGoogleLinked,
      'is_apple_linked': isAppleLinked,
      'has_password': hasPassword,
      'needs_onboarding': needsOnboarding,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? name,
    bool? isActive,
    String? avatarUrl,
    String? createdAt,
    String? appleId,
    String? googleId,
    bool? isEmailVerified,
    bool? isGoogleLinked,
    bool? isAppleLinked,
    bool? hasPassword,
    bool? needsOnboarding,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      appleId: appleId ?? this.appleId,
      googleId: googleId ?? this.googleId,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isGoogleLinked: isGoogleLinked ?? this.isGoogleLinked,
      isAppleLinked: isAppleLinked ?? this.isAppleLinked,
      hasPassword: hasPassword ?? this.hasPassword,
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
    );
  }
}
