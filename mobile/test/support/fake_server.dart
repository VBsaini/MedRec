import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medrec/core/api_client.dart';
import 'package:medrec/core/session.dart';

/// A response from a [FakeServer] route. Returning a plain value from a route
/// means 200 with that value as the JSON body.
class Reply {
  const Reply(this.status, [this.body]);
  final int status;
  final Object? body;
}

typedef Route = FutureOr<Object?> Function(FakeRequest request);

/// One request the app made, as seen by the fake server.
class FakeRequest {
  FakeRequest(this.options, this.params);

  final RequestOptions options;

  /// Values of `:name` segments in the matched route.
  final Map<String, String> params;

  String get method => options.method;
  String get path => options.uri.path.replaceFirst('/api', '');
  Map<String, dynamic> get json =>
      options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : const {};
  FormData? get form => options.data is FormData ? options.data as FormData : null;
  String? get authorization => options.headers['Authorization'] as String?;
}

/// Stands in for the network under [ApiClient]: routes like
/// `on('GET', '/reports/:id', ...)` answer requests, everything else is a
/// JSON 404, and [down] simulates an unreachable server.
class FakeServer implements HttpClientAdapter {
  final _routes = <(String, List<String>, Route)>[];
  final requests = <FakeRequest>[];

  /// When set, every request fails as if the server could not be reached.
  bool down = false;

  /// When set, every request times out.
  bool slow = false;

  void on(String method, String path, Route route) {
    _routes.add((method, _segments(path), route));
  }

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Drain the body so FormData uploads report progress and complete.
    await requestStream?.drain<void>();
    if (down) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
      );
    }
    if (slow) {
      throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 10),
        requestOptions: options,
      );
    }

    final path = _segments(options.uri.path.replaceFirst('/api', ''));
    for (final (method, pattern, route) in _routes) {
      if (method != options.method || pattern.length != path.length) continue;
      final params = <String, String>{};
      var matches = true;
      for (var i = 0; i < pattern.length; i++) {
        if (pattern[i].startsWith(':')) {
          params[pattern[i].substring(1)] = path[i];
        } else if (pattern[i] != path[i]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      final request = FakeRequest(options, params);
      requests.add(request);
      final result = await route(request);
      final reply = result is Reply ? result : Reply(200, result);
      return _json(reply.status, reply.body);
    }
    requests.add(FakeRequest(options, const {}));
    return _json(404, {'message': 'Not found'});
  }

  static ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Provider overrides that make the app talk to [server] and keep its
/// "secure storage" in memory, starting from [stored] (e.g. a saved token).
List<Override> fakeBackendOverrides(
  FakeServer server, {
  Map<String, String> stored = const {},
}) {
  FlutterSecureStorage.setMockInitialValues(Map.of(stored));
  return [
    apiClientProvider.overrideWith(
      (ref) => ApiClient(ref.watch(sessionProvider), adapter: server),
    ),
  ];
}
