import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/core/api_client.dart';
import 'package:medrec/core/session.dart';
import 'package:medrec/features/auth/auth_controller.dart';

import '../support/fake_server.dart';

const _user = {'_id': 'u1', 'name': 'Asha Rao', 'email': 'asha@example.com'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServer server;

  ProviderContainer start({Map<String, String> stored = const {}}) {
    final container = ProviderContainer(
      overrides: fakeBackendOverrides(server, stored: stored),
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reads the auth state once the start-up check has finished.
  Future<AuthState> settled(ProviderContainer container) async {
    if (container.read(authControllerProvider) is! AuthLoading) {
      return container.read(authControllerProvider);
    }
    final done = Completer<AuthState>();
    final sub = container.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is! AuthLoading && !done.isCompleted) done.complete(next);
    });
    final state = await done.future.timeout(const Duration(seconds: 5));
    sub.close();
    return state;
  }

  setUp(() {
    server = FakeServer();
    server.on('GET', '/auth/me', (r) {
      return r.authorization == 'Bearer good'
          ? _user
          : const Reply(401, {'message': 'Session expired. Please log in again.'});
    });
  });

  group('on start-up', () {
    test('no saved login means signed out, without calling the server', () async {
      final container = start();
      expect(await settled(container), isA<SignedOut>());
      expect(server.requests, isEmpty);
    });

    test('a saved, valid login restores the patient', () async {
      final container = start(stored: {'token': 'good'});
      final state = await settled(container);
      expect(state, isA<SignedIn>());
      expect((state as SignedIn).patient.name, 'Asha Rao');
      expect(container.read(patientProvider).id, 'u1');
    });

    test('an expired login signs out and forgets the token', () async {
      final container = start(stored: {'token': 'expired'});
      expect(await settled(container), isA<SignedOut>());
      expect(container.read(sessionProvider).token, isNull);
    });

    test('an unreachable server keeps the login and reports the problem', () async {
      server.down = true;
      final container = start(stored: {'token': 'good'});
      final state = await settled(container);
      expect(state, isA<AuthUnavailable>());
      expect((state as AuthUnavailable).message, contains('Cannot reach'));
      expect(container.read(sessionProvider).token, 'good');

      // "Try again" once the server is back.
      server.down = false;
      await container.read(authControllerProvider.notifier).restore();
      expect(container.read(authControllerProvider), isA<SignedIn>());
    });
  });

  test('login stores the token and signs in', () async {
    server.on('POST', '/auth/login', (r) {
      expect(r.json, {'email': 'asha@example.com', 'password': 'secret123'});
      return {'token': 'good', 'user': _user};
    });
    final container = start();
    await settled(container);

    await container
        .read(authControllerProvider.notifier)
        .login('asha@example.com', 'secret123');

    expect(container.read(authControllerProvider), isA<SignedIn>());
    expect(container.read(sessionProvider).token, 'good');
  });

  test('a failed login leaves the app signed out', () async {
    server.on(
      'POST',
      '/auth/login',
      (_) => const Reply(401, {'message': 'Invalid email or password.'}),
    );
    final container = start();
    await settled(container);

    await expectLater(
      container.read(authControllerProvider.notifier).login('a@b.c', 'nope'),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(authControllerProvider), isA<SignedOut>());
  });

  test('signup sends every field and signs in', () async {
    server.on('POST', '/auth/signup', (r) {
      expect(r.json.keys, containsAll(['name', 'alias', 'email', 'password']));
      return Reply(201, {'token': 'good', 'user': _user});
    });
    final container = start();
    await settled(container);

    await container
        .read(authControllerProvider.notifier)
        .signup(
          name: 'Asha Rao',
          alias: 'asha',
          email: 'asha@example.com',
          password: 'secret123',
        );
    expect(container.read(authControllerProvider), isA<SignedIn>());
  });

  test('a 401 on any later request logs the user out', () async {
    server.on('GET', '/me', (_) => const Reply(401, {'message': 'Session expired.'}));
    final container = start(stored: {'token': 'good'});
    await settled(container);

    await expectLater(
      container.read(authControllerProvider.notifier).refresh(),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(authControllerProvider), isA<SignedOut>());
    expect(container.read(sessionProvider).token, isNull);
  });

  test('setPatient replaces the record only while signed in', () async {
    final container = start(stored: {'token': 'good'});
    await settled(container);
    final auth = container.read(authControllerProvider.notifier);

    auth.setPatient({..._user, 'blood_group': 'B+'});
    expect(container.read(patientProvider).bloodGroup, 'B+');

    await auth.logout();
    auth.setPatient(_user);
    expect(container.read(authControllerProvider), isA<SignedOut>());
  });
}
