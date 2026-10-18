import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-202: LogEntry Unit Tests', () {
    test('1. Khởi tạo LogEntry với đầy đủ thông tin và kiểm tra các getter',
        () {
      final now = DateTime(2026, 10, 14, 12, 30, 45);
      final entry = LogEntry(
        timestamp: now,
        severity: Severity.error,
        code: 'SERVER_ERROR',
        errorType: 'ServerException',
        message: 'Internal server error 500',
        source: 'FakeRemoteDataSource',
        stackTrace: '#0 fake stack trace',
        originalError: 'HttpStatusError(500)',
      );

      expect(entry.timestamp, equals(now));
      expect(entry.severity, equals(Severity.error));
      expect(entry.code, equals('SERVER_ERROR'));
      expect(entry.errorType, equals('ServerException'));
      expect(entry.message, equals('Internal server error 500'));
      expect(entry.source, equals('FakeRemoteDataSource'));
      expect(entry.stackTrace, equals('#0 fake stack trace'));
      expect(entry.originalError, equals('HttpStatusError(500)'));
    });

    test(
        '2. Round-trip serialization: toJson -> fromJson bảo toàn nguyên vẹn dữ liệu',
        () {
      final now = DateTime.parse('2026-10-14T10:15:30.000Z');
      final entry = LogEntry(
        timestamp: now,
        severity: Severity.critical,
        code: 'UNKNOWN_ERROR',
        errorType: 'UnknownException',
        message: 'Something crashed',
        source: 'TransactionRepositoryImpl',
        stackTrace: 'trace lines...',
        originalError: 'Fatal crash',
      );

      final json = entry.toJson();
      final restored = LogEntry.fromJson(json);

      expect(restored, equals(entry));
      expect(restored.timestamp, equals(now));
      expect(restored.severity, equals(Severity.critical));
      expect(restored.code, equals('UNKNOWN_ERROR'));
      expect(restored.source, equals('TransactionRepositoryImpl'));
    });

    test('3. Round-trip với các trường tùy chọn mang giá trị null', () {
      final now = DateTime.parse('2026-10-14T08:00:00.000Z');
      final entry = LogEntry(
        timestamp: now,
        severity: Severity.warning,
        code: 'NETWORK_ERROR',
        errorType: 'NetworkException',
        message: 'No internet connection',
      );

      final json = entry.toJson();
      expect(json.containsKey('source'), isFalse);
      expect(json.containsKey('stackTrace'), isFalse);
      expect(json.containsKey('originalError'), isFalse);

      final restored = LogEntry.fromJson(json);
      expect(restored.source, isNull);
      expect(restored.stackTrace, isNull);
      expect(restored.originalError, isNull);
      expect(restored, equals(entry));
      expect(restored.hashCode, equals(entry.hashCode));
    });

    test('4. toString chứa đầy đủ thông tin tóm tắt', () {
      final now = DateTime(2026, 1, 1);
      final entry = LogEntry(
        timestamp: now,
        severity: Severity.info,
        code: 'VALIDATION_ERROR',
        errorType: 'ValidationException',
        message: 'Tiêu đề không hợp lệ',
        source: 'AddTransaction',
      );

      final str = entry.toString();
      expect(str, contains('INFO'));
      expect(str, contains('ValidationException'));
      expect(str, contains('VALIDATION_ERROR'));
      expect(str, contains('AddTransaction'));
    });
  });
}
