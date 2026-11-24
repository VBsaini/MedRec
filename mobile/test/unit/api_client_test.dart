import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/core/api_client.dart';
import 'package:medrec/core/session.dart';

import '../support/fake_server.dart';

void main() {
  late FakeServer server;
  late Session session;
  late ApiClient api;

  setUp(() {
    server = FakeServer();
    session = Session()..baseUrl = 'http://medrec.test:5000';
    api = ApiClient(session, adapter: server);
  });

  test('sends requests to <server>/api with the login token', () async {
    server.on('GET', '/reports', (_) => ['r1']);
    session.token = 'abc';

    expect(await api.get('/reports'), ['r1']);
    final request = server.requests.single;
    expect(
      request.options.uri.toString(),
      'http://medrec.test:5000/api/reports',
    );
    expect(request.authorization, 'Bearer abc');
  });

  test('sends no Authorization header when logged out', () async {
    server.on('POST', '/auth/login', (r) => {'echo': r.json});
    final data = await api.post('/auth/login', data: {'email': 'a@b.c'});
    expect(data, {
      'echo': {'email': 'a@b.c'},
    });
    expect(server.requests.single.authorization, isNull);
  });

  test('uses the server address saved at the time of the request', () async {
    server.on('GET', '/health', (_) => {'status': 'ok'});
    session.baseUrl = 'http://192.168.1.20:5000';
    await api.get('/health');
    expect(server.requests.single.options.uri.host, '192.168.1.20');
  });

  group('errors become ApiException', () {
    test('with the server message and status', () async {
      server.on(
        'POST',
        '/auth/login',
        (_) => const Reply(401, {'message': 'Invalid email or password.'}),
      );
      await expectLater(
        api.post('/auth/login', data: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Invalid email or password.')
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', true),
        ),
      );
    });

    test('with a generic message when the body has none', () async {
      server.on('GET', '/me', (_) => const Reply(502, 'Bad gateway'));
      await expectLater(
        api.get('/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Something went wrong (502).')
              .having((e) => e.statusCode, 'status', 502),
        ),
      );
    });

    test('naming the address when the server cannot be reached', () async {
      server.down = true;
      await expectLater(
        api.get('/me'),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.message,
                'message',
                startsWith('Cannot reach the server at http://medrec.test:5000'),
              )
              .having((e) => e.statusCode, 'status', isNull),
        ),
      );
    });

    test('saying it took too long on a timeout', () async {
      server.slow = true;
      await expectLater(
        api.get('/me'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'The server at http://medrec.test:5000 took too long to respond.',
          ),
        ),
      );
    });
  });

  group('a rejected login token', () {
    test('signs the app out', () async {
      var signedOut = 0;
      session
        ..token = 'expired'
        ..onUnauthorized = () => signedOut++;
      server.on('GET', '/me', (_) => const Reply(401, {'message': 'Session expired.'}));

      await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
      expect(signedOut, 1);
    });

    test('but a wrong password on the login screen does not', () async {
      var signedOut = 0;
      session.onUnauthorized = () => signedOut++;
      server.on('POST', '/auth/login', (_) => const Reply(401, {'message': 'Invalid'}));

      await expectLater(api.post('/auth/login'), throwsA(isA<ApiException>()));
      expect(signedOut, 0);
    });
  });
}
