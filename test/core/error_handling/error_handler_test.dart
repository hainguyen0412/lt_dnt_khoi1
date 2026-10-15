import 'dart:io';

import 'package:expense_tracker/core/error_handling/error_handler.dart';
import 'package:expense_tracker/core/error_handling/error_logger.dart';
import 'package:expense_tracker/core/error_handling/error_message_mapper.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lớp Logger giả lập phục vụ kiểm tra việc tiếp nhận và xử lý LogEntry.
class FakeErrorLogger implements ErrorLogger {
  final List<LogEntry> loggedEntries = <LogEntry>[];
  final bool shouldThrow;
  final void Function(LogEntry entry)? onLog;

  FakeErrorLogger({this.shouldThrow = false, this.onLog});

  @override
  Future<void> log(LogEntry entry) async {
    if (shouldThrow) {
      throw const FileSystemException('Fake disk I/O error');
    }
    loggedEntries.add(entry);
    onLog?.call(entry);
  }

  @override
  Future<List<LogEntry>> readAll() async => List.unmodifiable(loggedEntries);

  @override
  Future<void> clear() async => loggedEntries.clear();
}

/// Mapper bị lỗi giả lập để kiểm tra cơ chế phòng vệ an toàn (fallback) của pipeline.
class BrokenMessageMapper extends ErrorMessageMapper {
  const BrokenMessageMapper();

  @override
  String messageFor(AppException e) {
    throw StateError('Simulated crash inside ErrorMessageMapper');
  }
}

void main() {
  group('T-204: ErrorHandler Centralized Pipeline Unit Tests', () {
    late FakeErrorLogger logger1;
    late FakeErrorLogger logger2;
    late ErrorMessageMapper messageMapper;
    late ErrorHandler errorHandler;

    setUp(() {
      logger1 = FakeErrorLogger();
      logger2 = FakeErrorLogger();
      messageMapper = const ErrorMessageMapper();
      errorHandler = ErrorHandler(
        loggers: [logger1, logger2],
        messageMapper: messageMapper,
      );
    });

    test(
        'a) Bảng kiểm thử mọi loại AppException qua pipeline (message, canRetry, severity)',
        () async {
      final testCases = <({
        AppException exception,
        String expectedMessage,
        bool expectedCanRetry,
        Severity expectedSeverity,
      })>[
        (
          exception: const NetworkException(message: 'Network drop'),
          expectedMessage:
              'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
          expectedCanRetry: true,
          expectedSeverity: Severity.warning,
        ),
        (
          exception: const RequestTimeoutException(message: 'Timeout 5000ms'),
          expectedMessage: 'Máy chủ phản hồi quá chậm. Vui lòng thử lại.',
          expectedCanRetry: true,
          expectedSeverity: Severity.warning,
        ),
        (
          exception:
              ServerException(statusCode: 500, message: 'Server 500 crash'),
          expectedMessage: 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
          expectedCanRetry: true,
          expectedSeverity: Severity.error,
        ),
        (
          exception:
              ServerException(statusCode: 400, message: 'Bad request param'),
          expectedMessage: 'Yêu cầu không hợp lệ.',
          expectedCanRetry: false,
          expectedSeverity: Severity.warning,
        ),
        (
          exception: const ParseException(message: 'Invalid JSON schema'),
          expectedMessage: 'Dữ liệu nhận về không đúng định dạng.',
          expectedCanRetry: false,
          expectedSeverity: Severity.error,
        ),
        (
          exception: const CacheException(message: 'Disk write failed'),
          expectedMessage: 'Không đọc được dữ liệu lưu trên máy.',
          expectedCanRetry: false,
          expectedSeverity: Severity.error,
        ),
        (
          exception: const ValidationException(
            field: 'amount',
            message: 'Số tiền giao dịch phải lớn hơn 0.',
          ),
          expectedMessage: 'Số tiền giao dịch phải lớn hơn 0.',
          expectedCanRetry: false,
          expectedSeverity: Severity.info,
        ),
        (
          exception: const NotFoundException(message: 'Transaction not found'),
          expectedMessage: 'Không tìm thấy dữ liệu yêu cầu.',
          expectedCanRetry: false,
          expectedSeverity: Severity.info,
        ),
        (
          exception: const UnknownException(message: 'Unexpected crash'),
          expectedMessage: 'Đã xảy ra lỗi không xác định.',
          expectedCanRetry: true,
          expectedSeverity: Severity.critical,
        ),
      ];

      for (final tc in testCases) {
        final result = await errorHandler.handle(
          tc.exception,
          StackTrace.current,
        );

        expect(result.message, equals(tc.expectedMessage));
        expect(result.canRetry, equals(tc.expectedCanRetry));
        expect(result.severity, equals(tc.expectedSeverity));
      }
    });

    test(
        'b) Chuẩn hóa các lỗi thô tầng thấp (SocketException, FormatException, StateError)',
        () async {
      // 1. SocketException -> NetworkException (canRetry: true, warning)
      const socketError = SocketException('Connection refused');
      final res1 = await errorHandler.handle(socketError, StackTrace.current);
      expect(res1.canRetry, isTrue);
      expect(res1.severity, equals(Severity.warning));
      expect(res1.message, contains('Không có kết nối mạng'));

      // 2. FormatException -> ParseException (canRetry: false, error)
      const formatError = FormatException('Unexpected character');
      final res2 = await errorHandler.handle(formatError, StackTrace.current);
      expect(res2.canRetry, isFalse);
      expect(res2.severity, equals(Severity.error));
      expect(res2.message, contains('không đúng định dạng'));

      // 3. StateError -> UnknownException (canRetry: true, critical)
      final stateError = StateError('Bad state');
      final res3 = await errorHandler.handle(stateError, StackTrace.current);
      expect(res3.canRetry, isTrue);
      expect(res3.severity, equals(Severity.critical));
      expect(res3.message, contains('lỗi không xác định'));
    });

    test(
        'c) LogEntry được gửi tới tất cả logger; logger đầu lỗi thì logger sau vẫn nhận (Fault Isolation)',
        () async {
      final brokenLogger = FakeErrorLogger(shouldThrow: true);
      final healthyLogger = FakeErrorLogger();

      final isolatedHandler = ErrorHandler(
        loggers: [brokenLogger, healthyLogger],
        messageMapper: messageMapper,
      );

      const ex = NetworkException(message: 'Testing isolation');
      final userError = await isolatedHandler.handle(
        ex,
        StackTrace.current,
        source: 'UnitTest',
      );

      // Handler vẫn trả kết quả thành công mà không bị crash
      expect(userError.canRetry, isTrue);

      // healthyLogger vẫn nhận được LogEntry đầy đủ thông tin
      expect(healthyLogger.loggedEntries.length, equals(1));
      final logged = healthyLogger.loggedEntries.first;
      expect(logged.code, equals('NETWORK_ERROR'));
      expect(logged.errorType, equals('NetworkException'));
      expect(logged.source, equals('UnitTest'));
    });

    test(
        'd) Quy tắc source "global" nâng mức độ nghiêm trọng lên tối thiểu error',
        () async {
      // 1. ValidationException gốc là info -> nâng lên error
      const infoEx =
          ValidationException(field: 'title', message: 'Lỗi tiêu đề');
      final resInfo = await errorHandler.handle(
        infoEx,
        StackTrace.current,
        source: 'global',
      );
      expect(resInfo.severity, equals(Severity.error));

      // 2. NetworkException gốc là warning -> nâng lên error
      const warnEx = NetworkException(message: 'Lỗi mạng');
      final resWarn = await errorHandler.handle(
        warnEx,
        StackTrace.current,
        source: 'global',
      );
      expect(resWarn.severity, equals(Severity.error));

      // 3. ParseException gốc là error -> giữ nguyên error
      const errorEx = ParseException(message: 'Lỗi parse');
      final resError = await errorHandler.handle(
        errorEx,
        StackTrace.current,
        source: 'global',
      );
      expect(resError.severity, equals(Severity.error));

      // 4. UnknownException gốc là critical -> giữ nguyên critical
      const critEx = UnknownException(message: 'Lỗi fatal');
      final resCrit = await errorHandler.handle(
        critEx,
        StackTrace.current,
        source: 'global',
      );
      expect(resCrit.severity, equals(Severity.critical));

      // 5. Khi source khác "global" (ví dụ: "AddTransaction") -> giữ nguyên severity gốc
      final resNormal = await errorHandler.handle(
        infoEx,
        StackTrace.current,
        source: 'AddTransaction',
      );
      expect(resNormal.severity, equals(Severity.info));
    });

    test(
        'e) Thứ tự các bước được kiểm chứng: Việc ghi log luôn hoàn thành trước khi trả UserFacingError',
        () async {
      bool logCalledBeforeReturn = false;

      final trackingLogger = FakeErrorLogger(
        onLog: (entry) {
          logCalledBeforeReturn = true;
        },
      );

      final trackingHandler = ErrorHandler(
        loggers: [trackingLogger],
        messageMapper: messageMapper,
      );

      final result = await trackingHandler.handle(
        const NetworkException(message: 'Ordering test'),
        StackTrace.current,
      );

      expect(logCalledBeforeReturn, isTrue);
      expect(result.canRetry, isTrue);
      expect(trackingLogger.loggedEntries.length, equals(1));
    });

    test(
        'f) Pipeline phòng thủ tuyệt đối: Không ném lỗi ra ngoài ngay cả khi MessageMapper bị crash',
        () async {
      final brokenHandler = ErrorHandler(
        loggers: [logger1],
        messageMapper: const BrokenMessageMapper(),
      );

      // Dù mapper quăng StateError bên trong, handle() vẫn trả về fallback an toàn
      final fallbackResult = await brokenHandler.handle(
        const NetworkException(message: 'Crash test'),
        StackTrace.current,
      );

      expect(fallbackResult.message, equals('Đã xảy ra lỗi không xác định.'));
      expect(fallbackResult.canRetry, isFalse);
      expect(fallbackResult.severity, equals(Severity.critical));
    });
  });
}
