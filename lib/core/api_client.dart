import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../state/auth_notifier.dart';
import 'api_exceptions.dart';
import 'config.dart';

typedef TokenProvider = String? Function();

Dio buildDio({
  TokenProvider? tokenProvider,
  AuthNotifier? Function()? authProvider,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          debugPrint('[API] → ${options.method} ${options.uri}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        if (kDebugMode) {
          debugPrint(
            '[API] ← ${response.statusCode} ${response.requestOptions.uri}',
          );
        }
        final status = response.statusCode ?? 0;
        final path = response.requestOptions.path;
        final alreadyRetried =
            response.requestOptions.extra['authRetried'] == true;
        final isAuthCall =
            path.contains('auth-with-password') ||
            path.contains('auth-refresh') ||
            path.contains('/shop/login') ||
            path.contains('/shop/register');
        if (status == 401 &&
            authProvider != null &&
            !isAuthCall &&
            !alreadyRetried) {
          final auth = authProvider();
          if (auth != null) {
            final ok = await auth.refreshSession();
            if (ok) {
              final req = response.requestOptions;
              req.headers['Authorization'] = 'Bearer ${auth.accessToken}';
              req.extra['authRetried'] = true;
              try {
                final clone = await dio.fetch(req);
                return handler.resolve(clone);
              } catch (e) {
                return handler.reject(
                  DioException(
                    requestOptions: req,
                    error: e,
                    type: DioExceptionType.unknown,
                  ),
                );
              }
            }
          }
        }
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('[API] сбой ${error.requestOptions.uri}: ${error.type}');
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType
        .receiveTimeout => const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
      'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
    ),
    DioExceptionType.cancel => const CancelledException(),
    _ => const ServerException(),
  };
}

/// Повтор только для чтения: до 3 попыток с нарастающей паузой.
/// Отменённые запросы (CancelToken) не повторяем.
Future<T> guardRead<T>(Future<T> Function() action) async {
  var attempt = 0;
  while (true) {
    try {
      return await guard(action);
    } on CancelledException {
      rethrow;
    } on NetworkException {
      attempt++;
      if (attempt >= 3) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
    }
  }
}
