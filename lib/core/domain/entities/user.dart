class AppUser {
  final String id;
  final String email;
  final String? username;
  final String? avatarUrl;
  final DateTime createdAt;
  final Map<String, dynamic> profileData;

  const AppUser({
    required this.id,
    required this.email,
    this.username,
    this.avatarUrl,
    required this.createdAt,
    this.profileData = const {},
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      profileData: json['profileData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'profileData': profileData,
    };
  }
}
