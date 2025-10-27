import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:homecare_app/Services/token_storage.dart';

void main() {
  const token = 'test-token';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveToken persists token and getToken retrieves it', () async {
    final storage = TokenStorage.instance;

    await storage.saveToken(token);
    final storedToken = await storage.getToken();

    expect(storedToken, token);
  });

  test('clearToken removes stored token', () async {
    final storage = TokenStorage.instance;

    await storage.saveToken(token);
    await storage.clearToken();

    final storedToken = await storage.getToken();

    expect(storedToken, isNull);
  });
}
