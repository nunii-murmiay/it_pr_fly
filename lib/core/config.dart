/// Supabase: задаётся через --dart-define или значения по умолчанию ниже.
/// После создания проекта вставьте свои URL и anon key (не service_role!).
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://geohvkrcxxkyermfbayh.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdlb2h2a3JjeHhreWVybWZiYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0ODUwNDQsImV4cCI6MjEwNzA2MTA0NH0.bFkL8GG8PEhURGMH6ywRsZpvLwxZ0MLMkcJ5_cNPgrs',
);

/// Домен email для коротких логинов: librarian → librarian@zoomag.local
const String authEmailDomain = 'zoomag.local';

String identityToEmail(String identity) {
  final v = identity.trim();
  if (v.contains('@')) return v.toLowerCase();
  return '${v.toLowerCase()}@$authEmailDomain';
}
