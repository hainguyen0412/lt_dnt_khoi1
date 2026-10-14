import 'dart:async';
import 'dart:io';

import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/errors/cache_storage_error.dart';
import 'package:expense_tracker/core/errors/http_status_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-102: AppException & ExceptionFactory Tests', () {
    test('1. Đã là AppException -> trả đúng instance gốc (identical)', () {
      const original = NetworkException(message: 'Original network error');
      final result = AppException.from(original);

      expect(identical(result, original), isTrue);
      expect(result.code, equals('NETWORK_ERROR'));
      expect(result.severity, equals(Severity.warning));
    });

    test(
        '2. SocketException -> NetworkException (warning, originalError, stackTrace)',
        () {
      const error = SocketException('Connection refused');
      final customSt = StackTrace.fromString('custom-stack-trace-socket');
      final result = AppException.from(error, customSt);

      expect(result, isA<NetworkException>());
      expect(result.code, equals('NETWORK_ERROR'));
      expect(result.severity, equals(Severity.warning));
      expect(identical(result.originalError, error), isTrue);
      expect(result.stackTrace, equals(customSt));
      expect(result.toString(), contains('NetworkException(NETWORK_ERROR):'));
    });

    test('3. HttpException -> NetworkException (warning, originalError)', () {
      const error = HttpException('Connection closed prematurely');
      final result = AppException.from(error);

      expect(result, isA<NetworkException>());
      expect(result.code, equals('NETWORK_ERROR'));
      expect(result.severity, equals(Severity.warning));
      expect(identical(result.originalError, error), isTrue);
      expect(result.stackTrace, isNotNull);
    });

    test('4. HandshakeException -> NetworkException (warning, originalError)',
        () {
      const error = HandshakeException('TLS handshake failed');
      final result = AppException.from(error);

      expect(result, isA<NetworkException>());
      expect(result.code, equals('NETWORK_ERROR'));
      expect(result.severity, equals(Severity.warning));
      expect(identical(result.originalError, error), isTrue);
    });

    test(
        '5. TimeoutException (dart:async) -> RequestTimeoutException (warning)',
        () {
      final error = TimeoutException('Request timeout after 5000ms');
      final result = AppException.from(error);

      expect(result, isA<RequestTimeoutException>());
      expect(result.code, equals('REQUEST_TIMEOUT'));
      expect(result.severity, equals(Severity.warning));
      expect(identical(result.originalError, error), isTrue);
    });

    test('6. HttpStatusError(404) -> NotFoundException (info)', () {
      const error = HttpStatusError(404, 'Transaction with id 123 not found');
      final result = AppException.from(error);

      expect(result, isA<NotFoundException>());
      expect(result.code, equals('NOT_FOUND'));
      expect(result.severity, equals(Severity.info));
      expect(identical(result.originalError, error), isTrue);
    });

    test(
        '7. HttpStatusError(400) -> ServerException (warning, isClientError = true)',
        () {
      const error = HttpStatusError(400, 'Invalid request payload');
      final result = AppException.from(error);

      expect(result, isA<ServerException>());
      final serverEx = result as ServerException;
      expect(serverEx.code, equals('SERVER_ERROR'));
      expect(serverEx.statusCode, equals(400));
      expect(serverEx.severity, equals(Severity.warning));
      expect(serverEx.isClientError, isTrue);
      expect(serverEx.isServerError, isFalse);
      expect(identical(serverEx.originalError, error), isTrue);
    });

    test(
        '8. HttpStatusError(500) -> ServerException (error, isServerError = true)',
        () {
      const error = HttpStatusError(500, 'Internal server error');
      final result = AppException.from(error);

      expect(result, isA<ServerException>());
      final serverEx = result as ServerException;
      expect(serverEx.code, equals('SERVER_ERROR'));
      expect(serverEx.statusCode, equals(500));
      expect(serverEx.severity, equals(Severity.error));
      expect(serverEx.isClientError, isFalse);
      expect(serverEx.isServerError, isTrue);
      expect(identical(serverEx.originalError, error), isTrue);
    });

    test(
        '9. HttpStatusError(503) -> ServerException (error, isServerError = true)',
        () {
      const error = HttpStatusError(503, 'Service unavailable');
      final result = AppException.from(error);

      expect(result, isA<ServerException>());
      final serverEx = result as ServerException;
      expect(serverEx.statusCode, equals(503));
      expect(serverEx.severity, equals(Severity.error));
      expect(serverEx.isServerError, isTrue);
    });

    test('10. CacheStorageError -> CacheException (error, originalError)', () {
      const error = CacheStorageError('Disk full', 'Errno 28');
      final result = AppException.from(error);

      expect(result, isA<CacheException>());
      expect(result.code, equals('CACHE_ERROR'));
      expect(result.severity, equals(Severity.error));
      expect(identical(result.originalError, error), isTrue);
    });

    test('11. FormatException -> ParseException (error, originalError)', () {
      const error = FormatException('Unexpected character at line 1');
      final result = AppException.from(error);

      expect(result, isA<ParseException>());
      expect(result.code, equals('PARSE_ERROR'));
      expect(result.severity, equals(Severity.error));
      expect(identical(result.originalError, error), isTrue);
    });

    test(
        '12. TypeError -> UnknownException (critical, fallback stackTrace từ Error)',
        () {
      late final TypeError typeError;
      try {
        dynamic bad = 'not an int';
        // ignore: unused_local_variable
        int val = bad as int;
      } on TypeError catch (e) {
        typeError = e;
      }

      final result = AppException.from(typeError);

      expect(result, isA<UnknownException>());
      expect(result.code, equals('UNKNOWN_ERROR'));
      expect(result.severity, equals(Severity.critical));
      expect(identical(result.originalError, typeError), isTrue);
      expect(result.stackTrace, isNotNull);
    });

    test(
        '13. Lỗi không xác định khác -> UnknownException (critical, originalError)',
        () {
      final customError = Exception('Custom unhandled exception');
      final result = AppException.from(customError);

      expect(result, isA<UnknownException>());
      expect(result.code, equals('UNKNOWN_ERROR'));
      expect(result.severity, equals(Severity.critical));
      expect(identical(result.originalError, customError), isTrue);
    });

    test('14. ValidationException có field và severity info', () {
      const validationEx = ValidationException(
        message: 'Amount must be positive',
        field: 'amount',
      );

      expect(validationEx.code, equals('VALIDATION_ERROR'));
      expect(validationEx.severity, equals(Severity.info));
      expect(validationEx.field, equals('amount'));
      expect(
          validationEx.toString(),
          equals(
              'ValidationException(VALIDATION_ERROR): Amount must be positive'));
    });
  });
}
