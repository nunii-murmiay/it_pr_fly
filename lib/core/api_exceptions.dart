import 'pb_ids.dart';

/// Исключения предметной области (виджеты не знают про Dio).
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Сервер недоступен. Проверьте соединение. '
            'Если сервер запущен, откройте консоль браузера и проверьте CORS.',
  ]);
}

/// Отмена устаревшего запроса (CancelToken) — не ошибка для UI.
class CancelledException extends ApiException {
  const CancelledException([super.message = 'Запрос отменён.']);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  final String? productId;

  const ConflictException(super.message, {this.productId});
}

class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

Map<String, String> _pbFieldErrors(dynamic body) {
  if (body is! Map) return const {};
  final data = body['data'];
  if (data is Map) {
    return data.map((k, v) {
      if (v is Map && v['message'] != null) {
        return MapEntry('$k', '${v['message']}');
      }
      return MapEntry('$k', '$v');
    });
  }
  if (body['errors'] is Map) {
    return (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'));
  }
  return const {};
}

ApiException mapHttpError(int status, dynamic body) {
  final message =
      (body is Map && body['message'] is String)
          ? body['message'] as String
          : null;
  final fieldErrors = _pbFieldErrors(body);

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(
      message ?? 'Операция невозможна.',
      productId:
          (body is Map && body['productId'] != null)
              ? pbId(body['productId'])
              : null,
    ),
    400 ||
    422 => ValidationException(message ?? 'Ошибка валидации', fieldErrors),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}
