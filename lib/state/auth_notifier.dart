import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_api.dart';
import '../core/api_exceptions.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../models/role.dart';

class AuthNotifier extends ChangeNotifier {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user';
  static const _kLastActivity = 'auth_last_activity';
  static const _kSessionStarted = 'auth_session_started';

  static const maxSessionDuration = Duration(hours: 2);
  static const inactivityTimeout = Duration(minutes: 3);
  static const inactivityWarning = Duration(seconds: 30);

  final SharedPreferences _prefs;
  final AuthApi _api;

  AuthNotifier(this._prefs, this._api);

  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _restoring = true;
  bool _refreshing = false;
  Future<void>? _refreshInFlight;
  String? _sessionMessage;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null && _accessToken != null;
  bool get isRestoring => _restoring;
  bool get isRefreshing => _refreshing;
  String? get sessionMessage => _sessionMessage;

  bool has(Role role) => _user != null && _user!.role.atLeast(role);

  bool can(AppOperation op) =>
      _user != null && Permissions.can(_user!.role, op);

  void clearSessionMessage() {
    _sessionMessage = null;
  }

  Future<void> restore() async {
    _restoring = true;
    notifyListeners();

    final access = _prefs.getString(_kAccess);
    final refresh = _prefs.getString(_kRefresh);
    if (access == null) {
      _restoring = false;
      notifyListeners();
      return;
    }

    if (_isMaxSessionExceeded() || _isInactivityExceeded()) {
      await logout(
        message:
            _isMaxSessionExceeded()
                ? 'Сессия завершена: истекло максимальное время входа.'
                : 'Сессия завершена из‑за отсутствия активности.',
      );
      _restoring = false;
      notifyListeners();
      return;
    }

    _accessToken = access;
    _refreshToken = refresh;

    final cached = _prefs.getString(_kUser);
    if (cached != null) {
      try {
        _user = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      } catch (_) {}
    }

    if (_isJwtExpired(access)) {
      if (refresh != null) {
        try {
          await _refreshWith(refresh);
        } catch (_) {
          await logout(message: 'Сессия истекла. Войдите снова.');
        }
      } else {
        await logout(message: 'Сессия истекла. Войдите снова.');
      }
    } else if (_user == null) {
      try {
        _user = await _api.me();
        await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
      } on UnauthorizedException {
        if (refresh != null) {
          try {
            await _refreshWith(refresh);
          } catch (_) {
            await logout(message: 'Сессия истекла. Войдите снова.');
          }
        } else {
          await logout(message: 'Сессия истекла. Войдите снова.');
        }
      } catch (_) {}
    }

    _restoring = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final result = await _api.login(username, password);
    await _applyTokens(result);
    await _prefs.setInt(
      _kSessionStarted,
      DateTime.now().millisecondsSinceEpoch,
    );
    await touchActivity();
    _sessionMessage = null;
    notifyListeners();
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
  }) async {
    await _api.register(
      username: username,
      password: password,
      fullName: fullName,
      email: email,
    );
    await login(username, password);
  }

  Future<void> logout({String? message}) async {
    final refresh = _refreshToken;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _sessionMessage = message;
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kLastActivity);
    await _prefs.remove(_kSessionStarted);
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {}
    }
    notifyListeners();
  }

  DateTime? _lastTouchWrite;

  Future<void> touchActivity() async {
    final now = DateTime.now();
    if (_lastTouchWrite != null &&
        now.difference(_lastTouchWrite!) < const Duration(seconds: 1)) {
      return;
    }
    _lastTouchWrite = now;
    await _prefs.setInt(_kLastActivity, now.millisecondsSinceEpoch);
  }

  Future<bool> refreshSession() async {
    final refresh = _refreshToken ?? _prefs.getString(_kRefresh);
    if (refresh == null) return false;
    try {
      await _refreshWith(refresh);
      return true;
    } catch (_) {
      await logout(message: 'Не удалось обновить сессию. Войдите снова.');
      return false;
    }
  }

  Future<void> _refreshWith(String refresh) async {
    if (_refreshInFlight != null) {
      await _refreshInFlight;
      return;
    }
    _refreshing = true;
    _refreshInFlight = () async {
      final result = await _api.refresh(refresh);
      await _applyTokens(result);
    }();
    try {
      await _refreshInFlight;
    } finally {
      _refreshInFlight = null;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _applyTokens(AuthTokens result) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    await _prefs.setString(_kUser, jsonEncode(result.user.toJson()));
  }

  bool _isMaxSessionExceeded() {
    final started = _prefs.getInt(_kSessionStarted);
    if (started == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - started;
    return elapsed > maxSessionDuration.inMilliseconds;
  }

  bool _isInactivityExceeded() {
    final last = _prefs.getInt(_kLastActivity);
    if (last == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed > inactivityTimeout.inMilliseconds;
  }

  bool _isJwtExpired(String token) {
    try {
      // PocketBase — обычный JWT (payload во 2-й части). Старый mock — payload в 1-й.
      final parts = token.split('.');
      final body = parts.length >= 3 ? parts[1] : parts.first;
      final normalized = base64Url.normalize(body);
      final map = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = map['exp'];
      if (exp is! num) return true;
      return exp * 1000 < DateTime.now().millisecondsSinceEpoch + 5000;
    } catch (_) {
      return true;
    }
  }

  void reloadUserFromStorage() {
    final cached = _prefs.getString(_kUser);
    if (cached == null) return;
    try {
      _user = AppUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(cached) as Map),
      );
      notifyListeners();
    } catch (_) {}
  }
}
