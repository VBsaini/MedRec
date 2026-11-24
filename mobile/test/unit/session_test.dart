import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/core/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts with the default server and no login', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = Session();
    await session.load();
    expect(session.token, isNull);
    expect(session.baseUrl, defaultBaseUrl);
    expect(session.authHeaders, isEmpty);
  });

  test('a saved token and server survive an app restart', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await (Session()..token = null).saveToken('tok');
    await Session().saveBaseUrl('192.168.1.20:5000/api/');

    final restarted = Session();
    await restarted.load();
    expect(restarted.token, 'tok');
    expect(restarted.baseUrl, 'http://192.168.1.20:5000');
    expect(restarted.authHeaders, {'Authorization': 'Bearer tok'});
  });

  test('logging out removes the stored token', () async {
    FlutterSecureStorage.setMockInitialValues({'token': 'tok'});
    final session = Session();
    await session.load();
    await session.saveToken(null);

    final restarted = Session();
    await restarted.load();
    expect(restarted.token, isNull);
  });
}
