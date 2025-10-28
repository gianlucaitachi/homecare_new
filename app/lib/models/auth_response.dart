class AuthResponse {
  AuthResponse({
    required this.token,
    this.refreshToken,
    this.user,
    this.additionalData = const {},
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final rawToken = json['token'] ?? json['accessToken'];
    if (rawToken is! String || rawToken.isEmpty) {
      throw const FormatException('Missing token in authentication response');
    }
    Map<String, dynamic>? user;
    if (json['user'] is Map) {
      user = Map<String, dynamic>.from(json['user']);
    }
    final additionalData = <String, dynamic>{};
    json.forEach((key, value) {
      if (key == 'token' ||
          key == 'accessToken' ||
          key == 'refreshToken' ||
          key == 'user') {
        return;
      }
      additionalData[key] = value;
    });
    return AuthResponse(
      token: rawToken,
      refreshToken: json['refreshToken'] as String?,
      user: user,
      additionalData: additionalData,
    );
  }

  final String token;
  final String? refreshToken;
  final Map<String, dynamic>? user;
  final Map<String, dynamic> additionalData;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (user != null) 'user': user,
      ...additionalData,
    };
  }
}
