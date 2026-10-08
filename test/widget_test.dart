import 'package:flutter_application_1/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supabaseUrl и anon key задаются через fromEnvironment', () {
    expect(supabaseUrl, isNotEmpty);
    expect(supabaseAnonKey, isNotEmpty);
    expect(identityToEmail('librarian'), 'librarian@zoomag.local');
  });
}
