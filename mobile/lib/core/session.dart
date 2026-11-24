import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Default API address. Override at build time with
/// `--dart-define=API_BASE_URL=http://192.168.1.20:5000`, or at runtime from
/// the "Server address" link on the login screen.
///
/// 10.0.2.2 is how the Android emulator reaches the computer it runs on.
const defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

/// What the API client needs for every request: where the server is and who
/// is logged in. Kept in memory and mirrored to secure storage.
class Session {
  String baseUrl = defaultBaseUrl;
  String? token;

  /// Called when the server rejects our token, so the app can log out.
  void Function()? onUnauthorized;

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'token';
  static const _baseUrlKey = 'base_url';

  Future<void> load() async {
    token = await _storage.read(key: _tokenKey);
    baseUrl = await _storage.read(key: _baseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> saveToken(String? value) async {
    token = value;
    if (value == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: value);
    }
  }

  Future<void> saveBaseUrl(String value) async {
    baseUrl = normalizeBaseUrl(value);
    await _storage.write(key: _baseUrlKey, value: baseUrl);
  }

  Map<String, String> get authHeaders => {
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

/// Trims, drops trailing slashes and a trailing "/api", and assumes http://
/// when no scheme is given (the usual case for a LAN address).
String normalizeBaseUrl(String input) {
  var url = input.trim();
  if (!url.startsWith(RegExp(r'https?://'))) url = 'http://$url';
  url = url.replaceAll(RegExp(r'/+$'), '');
  if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
  return url;
}

final sessionProvider = Provider<Session>((ref) => Session());
