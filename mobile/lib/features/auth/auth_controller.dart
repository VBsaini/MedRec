import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/patient.dart';

sealed class AuthState {
  const AuthState();
}

/// Still checking for a saved login.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.patient);
  final Patient patient;
}

/// A login is saved but the server could not be reached to confirm it.
class AuthUnavailable extends AuthState {
  const AuthUnavailable(this.message);
  final String message;
}

class AuthController extends Notifier<AuthState> {
  Session get _session => ref.read(sessionProvider);
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  AuthState build() {
    _session.onUnauthorized = _handleUnauthorized;
    Future.microtask(restore);
    return const AuthLoading();
  }

  /// Loads the saved token (if any) and fetches the patient it belongs to.
  Future<void> restore() async {
    state = const AuthLoading();
    await _session.load();
    if (_session.token == null) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(_toPatient(await _api.get('/auth/me')));
    } on ApiException catch (e) {
      // A 401 has already signed us out via _handleUnauthorized.
      if (!e.isUnauthorized) state = AuthUnavailable(e.message);
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _startSession(data);
  }

  Future<void> signup({
    required String name,
    required String alias,
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/signup',
      data: {
        'name': name,
        'alias': alias,
        'email': email,
        'password': password,
      },
    );
    await _startSession(data);
  }

  Future<void> logout() async {
    await _session.saveToken(null);
    state = const SignedOut();
  }

  /// Re-fetches the whole record after something in it changed.
  Future<void> refresh() async {
    setPatient(await _api.get('/me'));
  }

  /// Uses a user document the server just returned as the current record.
  void setPatient(dynamic json) {
    if (state is SignedIn) state = SignedIn(_toPatient(json));
  }

  Future<void> setBaseUrl(String url) => _session.saveBaseUrl(url);

  Future<void> _startSession(dynamic data) async {
    await _session.saveToken(data['token'] as String);
    state = SignedIn(_toPatient(data['user']));
  }

  void _handleUnauthorized() {
    if (_session.token == null) return;
    logout();
  }

  Patient _toPatient(dynamic json) =>
      Patient(Map<String, dynamic>.from(json as Map));
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The logged-in patient. Only read this from screens behind the login.
///
/// Keeps returning the last patient for the moment between logging out and
/// the router leaving the signed-in screens, so they can still build.
final patientProvider = Provider<Patient>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is SignedIn) return _lastPatient = state.patient;
  final last = _lastPatient;
  if (last != null) return last;
  throw StateError('patientProvider read before login');
});

Patient? _lastPatient;
