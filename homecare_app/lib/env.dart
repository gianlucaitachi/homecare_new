class Env {
  Env._();

  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'http://localhost:8080');
}
