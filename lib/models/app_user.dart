import '../core/pb_ids.dart';
import 'role.dart';

class AppUser {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final Role role;
  final String? customerId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.customerId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: pbId(json['id']),
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: Role.fromApi(json['role'] as String?),
      customerId:
          json['customerId'] == null || json['customerId'] == ''
              ? null
              : pbId(json['customerId']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.apiName,
    'customerId': customerId,
  };

  AppUser copyWith({Role? role}) => AppUser(
    id: id,
    username: username,
    fullName: fullName,
    email: email,
    role: role ?? this.role,
    customerId: customerId,
  );
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AppUser user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
      user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }
}
