import '../state/auth_notifier.dart';

class AuthSession {
  AuthSession(this._auth) : _fixedToken = null;

  AuthSession.fixed(String? token) : _auth = null, _fixedToken = token;

  final AuthNotifier? _auth;
  final String? _fixedToken;

  String? get accessToken => _auth?.accessToken ?? _fixedToken;

  Future<void> ensureLibrarian() async {}
  Future<void> ensureAdmin() async {}
  Future<void> ensureLoggedIn({bool force = false}) async {}
}
