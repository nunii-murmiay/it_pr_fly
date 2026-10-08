/// Supabase: задаётся через --dart-define или значения по умолчанию ниже.
/// После создания проекта вставьте свои URL и anon key (не service_role!).
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR_PROJECT.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR_SUPABASE_ANON_KEY',
);

/// Домен email для коротких логинов: librarian → librarian@zoomag.local
const String authEmailDomain = 'zoomag.local';

String identityToEmail(String identity) {
  final v = identity.trim();
  if (v.contains('@')) return v.toLowerCase();
  return '${v.toLowerCase()}@$authEmailDomain';
}
