class AppUser {
  final String id;
  final String email;
  final String nickname;
  final DateTime dateOfBirth;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.nickname,
    required this.dateOfBirth,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayName => nickname.isNotEmpty ? nickname : email.split('@').first;
  String get initial => nickname.isNotEmpty ? nickname[0].toUpperCase() : email[0].toUpperCase();
}