import 'package:equatable/equatable.dart';

enum UserRole { user, admin }

class Profile extends Equatable {
  const Profile({
    required this.userId,
    required this.email,
    this.name,
    this.role = UserRole.user,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String email;
  final String? name;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == UserRole.admin;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.user,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'name': name,
        'role': role.name,
      };

  @override
  List<Object?> get props => [userId, email, name, role];
}
