import 'package:expense_tracker/core/error_handling/console_logger.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-202: ConsoleLogger Unit Tests', () {
    const logger = ConsoleLogger();

    test(
        '1. log() thực thi an toàn với mọi cấp độ Severity mà không ném ngoại lệ',
        () async {
      for (final severity in Severity.values) {
        final entry = LogEntry(
          timestamp: DateTime.now(),
          severity: severity,
          code: 'TEST_CODE',
          errorType: 'TestException',
          message: 'Testing severity ${severity.name}',
          source: 'ConsoleLoggerTest',
          stackTrace: '#0 test stack trace',
        );

        // Không ném ngoại lệ ra ngoài
        await expectLater(logger.log(entry), completes);
      }
    });

    test(
        '2. readAll() luôn trả về danh sách rỗng vì console không phải nơi lưu trữ',
        () async {
      final entries = await logger.readAll();
      expect(entries, isEmpty);
    });

    test('3. clear() hoàn thành bình thường (no-op)', () async {
      await expectLater(logger.clear(), completes);
    });
  });
}
