/// URL и anon-ключ Supabase (вшиты в сборку сайта).
/// Не используйте service_role. Кусок fromEnvironment убрали: на web
/// пустой dart-define давал пустой URL и ошибку Unexpected token html.
const String supabaseUrl = 'https://geohvkrcxxkyermfbayh.supabase.co';

const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdlb2h2a3JjeHhreWVybWZiYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0ODUwNDQsImV4cCI6MjEwNzA2MTA0NH0.bFkL8GG8PEhURGMH6ywRsZpvLwxZ0MLMkcJ5_cNPgrs';

/// Домен email для коротких логинов: librarian → librarian@zoomag.local
const String authEmailDomain = 'zoomag.local';

String identityToEmail(String identity) {
  final v = identity.trim();
  if (v.contains('@')) return v.toLowerCase();
  return '${v.toLowerCase()}@$authEmailDomain';
}
