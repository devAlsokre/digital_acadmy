import 'app_user_role.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String? email;
  final String? fullName;
  final AppUserRole role;

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      fullName: json['full_name']?.toString(),
      role: AppUserRole.fromValue(json['role']),
    );
  }
}
