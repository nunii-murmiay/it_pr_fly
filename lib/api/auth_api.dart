import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/supabase_map.dart';
import '../models/app_user.dart';

class AuthApi {
  AuthApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<AppUser> _profileFor(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).single();
    return AppUser.fromJson(mapProfileRow(Map<String, dynamic>.from(row)));
  }

  Future<AuthTokens> login(String username, String password) {
    return guardSb(() async {
      final email = identityToEmail(username);
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = res.session;
      final user = res.user;
      if (session == null || user == null) {
        throw const UnauthorizedException();
      }
      final appUser = await _profileFor(user.id);
      return AuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? session.accessToken,
        expiresIn: session.expiresIn ?? 3600,
        user: appUser,
      );
    });
  }

  Future<AppUser> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
  }) {
    return guardSb(() async {
      final login = username.trim().toLowerCase();
      final mail = email.trim().toLowerCase();
      final resolvedEmail = mail.contains('@') ? mail : identityToEmail(login);
      final res = await _client.auth.signUp(
        email: resolvedEmail,
        password: password,
        data: {'username': login, 'full_name': fullName, 'role': 'reader'},
      );
      final user = res.user;
      if (user == null) {
        throw const ServerException('Не удалось зарегистрироваться.');
      }

      final customer =
          await _client
              .from('customers')
              .insert({
                'full_name': fullName,
                'email': resolvedEmail,
                'phone': '+7 (000) 000-00-00',
              })
              .select()
              .single();
      final customerId = customer['id'] as String;
      await _client.from('loyalty_cards').insert({
        'number': 'LC-${customerId.substring(0, 8).toUpperCase()}',
        'points': 0,
        'level': 'Стандарт',
        'customer_id': customerId,
      });
      await _client
          .from('profiles')
          .update({
            'username': login,
            'full_name': fullName,
            'email': resolvedEmail,
            'role': 'reader',
            'customer_id': customerId,
          })
          .eq('id', user.id);

      return _profileFor(user.id);
    });
  }

  Future<AppUser> me() {
    return guardSb(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw const UnauthorizedException();
      return _profileFor(user.id);
    });
  }

  Future<AuthTokens> refresh(String refreshToken) {
    return guardSb(() async {
      final res = await _client.auth.refreshSession();
      final session = res.session;
      final user = res.user ?? _client.auth.currentUser;
      if (session == null || user == null) {
        throw const UnauthorizedException();
      }
      final appUser = await _profileFor(user.id);
      return AuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? refreshToken,
        expiresIn: session.expiresIn ?? 3600,
        user: appUser,
      );
    });
  }

  Future<void> logout(String? refreshToken) async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  Future<List<AppUser>> listUsers() {
    return guardSb(() async {
      final rows = await _client.from('profiles').select().order('username');
      return (rows as List)
          .whereType<Map>()
          .map(
            (e) =>
                AppUser.fromJson(mapProfileRow(Map<String, dynamic>.from(e))),
          )
          .toList();
    });
  }
}
