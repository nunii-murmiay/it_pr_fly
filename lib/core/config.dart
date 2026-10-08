/// Supabase: --dart-define или значения ниже.
/// Пустой dart-define НЕ должен затирать дефолт (так ломалась сборка Pages).
const String _envUrl = String.fromEnvironment('SUPABASE_URL');
const String _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const String _defaultUrl = 'https://geohvkrcxxkyermfbayh.supabase.co';
const String _defaultKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdlb2h2a3JjeHhreWVybWZiYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0ODUwNDQsImV4cCI6MjEwNzA2MTA0NH0.bFkL8GG8PEhURGMH6ywRsZpvLwxZ0MLMkcJ5_cNPgrs';

final String supabaseUrl = _envUrl.isEmpty ? _defaultUrl : _envUrl;
final String supabaseAnonKey = _envKey.isEmpty ? _defaultKey : _envKey;

/// Домен email для коротких логинов: librarian → librarian@zoomag.local
const String authEmailDomain = 'zoomag.local';

String identityToEmail(String identity) {
  final v = identity.trim();
  if (v.contains('@')) return v.toLowerCase();
  return '${v.toLowerCase()}@$authEmailDomain';
}
