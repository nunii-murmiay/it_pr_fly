import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/pb_ids.dart';
import '../models/app_user.dart';
import '../models/role.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  AppUser _userFromRecord(Map<String, dynamic> record) {
    final customer = pbId(record['customerId']);
    return AppUser(
      id: pbId(record['id']),
      username: record['username'] as String? ?? '',
      fullName: record['fullName'] as String? ?? '',
      email: record['email'] as String? ?? '',
      role: Role.fromApi(record['role'] as String?),
      customerId: customer.isEmpty ? null : customer,
    );
  }

  AuthTokens _tokensFromAuth(Map<String, dynamic> data) {
    final record = Map<String, dynamic>.from(data['record'] as Map);
    final token = data['token'] as String;
    return AuthTokens(
      accessToken: token,
      refreshToken: token,
      expiresIn: 60 * 60 * 24 * 14,
      user: _userFromRecord(record),
    );
  }

  Future<AuthTokens> login(String username, String password) {
    return guard(() async {
      final response = await _dio.post(
        '/shop/login',
        data: {'identity': username, 'password': password},
      );
      return _tokensFromAuth(Map<String, dynamic>.from(response.data as Map));
    });
  }

  Future<AppUser> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
  }) {
    return guard(() async {
      final response = await _dio.post(
        '/shop/register',
        data: {
          'username': username,
          'password': password,
          'fullName': fullName,
          'email': email,
        },
      );
      return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
    });
  }

  Future<AppUser> me() {
    return guard(() async {
      final response = await _dio.post('/collections/users/auth-refresh');
      final data = Map<String, dynamic>.from(response.data as Map);
      return _userFromRecord(Map<String, dynamic>.from(data['record'] as Map));
    });
  }

  Future<AuthTokens> refresh(String refreshToken) {
    return guard(() async {
      final response = await _dio.post(
        '/collections/users/auth-refresh',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );
      return _tokensFromAuth(Map<String, dynamic>.from(response.data as Map));
    });
  }

  Future<void> logout(String? refreshToken) async {}

  Future<List<AppUser>> listUsers() {
    return guard(() async {
      final response = await _dio.get(
        '/collections/users/records',
        queryParameters: {'perPage': 200, 'sort': 'username'},
      );
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => _userFromRecord(Map<String, dynamic>.from(e)))
          .toList();
    });
  }
}
