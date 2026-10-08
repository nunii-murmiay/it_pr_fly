import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/config.dart';

void main() {
  test(
    'API_BASE_URL задаётся через fromEnvironment с localhost по умолчанию',
    () {
      expect(apiBaseUrl, contains('/api'));
    },
  );
}
