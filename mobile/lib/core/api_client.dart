import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// An API failure with a message that is safe to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;

  /// HTTP status, or null when the server could not be reached at all.
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin wrapper around Dio for the MedRec API. Adds the server address and
/// login token to every request and turns failures into [ApiException]s.
class ApiClient {
  /// [adapter] replaces the network layer; tests use it to fake the server.
  ApiClient(this._session, {HttpClientAdapter? adapter}) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = '${_session.baseUrl}/api';
          options.headers.addAll(_session.authHeaders);
          handler.next(options);
        },
        onError: (error, handler) {
          final sentToken = error.requestOptions.headers.containsKey(
            'Authorization',
          );
          if (error.response?.statusCode == 401 && sentToken) {
            _session.onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Session _session;
  late final Dio _dio;

  Future<dynamic> get(String path) => _send(() => _dio.get(path));

  Future<dynamic> post(
    String path, {
    Object? data,
    ProgressCallback? onSendProgress,
  }) => _send(
    () => _dio.post(
      path,
      data: data,
      onSendProgress: onSendProgress,
      // Uploads over a slow connection can take a while.
      options:
          data is FormData
              ? Options(sendTimeout: const Duration(minutes: 5))
              : null,
    ),
  );

  Future<dynamic> put(String path, {Object? data}) =>
      _send(() => _dio.put(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => _dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  /// Downloads [path] to a local file.
  Future<void> download(String path, String savePath) =>
      _send(() => _dio.download(path, savePath));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      final message =
          data is Map && data['message'] is String
              ? data['message'] as String
              : 'Something went wrong (${response.statusCode}).';
      return ApiException(message, statusCode: response.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'The server at ${_session.baseUrl} took too long to respond.',
        );
      case DioExceptionType.cancel:
        return ApiException('Cancelled.');
      default:
        return ApiException(
          'Cannot reach the server at ${_session.baseUrl}. '
          'Check that it is running and that the server address is right.',
        );
    }
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionProvider)),
);
