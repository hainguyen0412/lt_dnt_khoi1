import 'dart:async';

import 'package:expense_tracker/core/error_handling/error_handler.dart';
import 'package:expense_tracker/core/error_handling/error_logger.dart';
import 'package:expense_tracker/core/error_handling/error_message_mapper.dart';
import 'package:expense_tracker/core/error_handling/global_error_hooks.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeErrorLogger implements ErrorLogger {
  final List<LogEntry> loggedEntries = <LogEntry>[];
  void Function(LogEntry entry)? onLog;

  @override
  Future<void> log(LogEntry entry) async {
    loggedEntries.add(entry);
    onLog?.call(entry);
  }

  @override
  Future<List<LogEntry>> readAll() async => List.unmodifiable(loggedEntries);

  @override
  Future<void> clear() async => loggedEntries.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T-205: GlobalErrorHooks Unit Tests', () {
    late FlutterExceptionHandler? originalFlutterOnError;
    late bool Function(Object, StackTrace)? originalPlatformDispatcherOnError;
    late FakeErrorLogger fakeLogger;
    late ErrorHandler errorHandler;

    setUp(() {
      // Lưu lại các handler gốc của môi trường test để khôi phục trong tearDown
      originalFlutterOnError = FlutterError.onError;
      originalPlatformDispatcherOnError = PlatformDispatcher.instance.onError;

      fakeLogger = FakeErrorLogger();
      errorHandler = ErrorHandler(
        loggers: [fakeLogger],
        messageMapper: const ErrorMessageMapper(),
      );
    });

    tearDown(() {
      // Bắt buộc khôi phục handler gốc để không làm ảnh hưởng các bộ test khác
      FlutterError.onError = originalFlutterOnError;
      PlatformDispatcher.instance.onError = originalPlatformDispatcherOnError;
    });

    test('1. FlutterError.onError đẩy lỗi qua handler với source là "global"',
        () async {
      GlobalErrorHooks.install(errorHandler);

      final completer = Completer<LogEntry>();
      fakeLogger.onLog = completer.complete;

      const testException =
          NetworkException(message: 'Widget build network error');
      const testDetails = FlutterErrorDetails(
        exception: testException,
        library: 'widget framework test',
      );

      // Kích hoạt hook của Flutter framework
      FlutterError.onError!(testDetails);

      final entry = await completer.future.timeout(const Duration(seconds: 2));

      expect(entry.source, equals('global'));
      expect(fakeLogger.loggedEntries.length, equals(1));
      // Quy tắc T-204: source "global" nâng mức độ nghiêm trọng từ warning lên tối thiểu error
      expect(entry.severity, equals(Severity.error));
    });

    test(
        '2. PlatformDispatcher.instance.onError trả về true và ghi log với source "global"',
        () async {
      GlobalErrorHooks.install(errorHandler);

      final completer = Completer<LogEntry>();
      fakeLogger.onLog = completer.complete;

      final testError = StateError('Unhandled async isolate error');
      final stack = StackTrace.current;

      // Kích hoạt hook của PlatformDispatcher
      final handled = PlatformDispatcher.instance.onError!(testError, stack);

      // BẮT BUỘC trả về true để báo cho Flutter engine biết lỗi đã được xử lý
      expect(handled, isTrue);

      final entry = await completer.future.timeout(const Duration(seconds: 2));

      expect(entry.source, equals('global'));
      expect(entry.errorType, equals('UnknownException'));
      expect(entry.severity, equals(Severity.critical));
      expect(fakeLogger.loggedEntries.length, equals(1));
    });

    test('3. runGuarded bọc runZonedGuarded bắt lỗi async unhandled trong Zone',
        () async {
      final completer = Completer<LogEntry>();
      fakeLogger.onLog = completer.complete;

      // Chạy một body có chứa lỗi async unhandled bên trong runGuarded
      GlobalErrorHooks.runGuarded(() async {
        // Mô phỏng tác vụ bất đồng bộ bắn lỗi không await
        scheduleMicrotask(() {
          throw const FormatException('Zone microtask error');
        });
      }, errorHandler);

      final entry = await completer.future.timeout(const Duration(seconds: 2));

      expect(entry.source, equals('global'));
      expect(entry.errorType, equals('ParseException'));
      expect(entry.severity, equals(Severity.error));
    });
  });
}
