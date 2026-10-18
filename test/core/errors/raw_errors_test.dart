import 'package:expense_tracker/core/errors/cache_storage_error.dart';
import 'package:expense_tracker/core/errors/http_status_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-401: Raw Errors Unit Tests', () {
    group('HttpStatusError', () {
      test(
          '1. Khởi tạo với statusCode và message, toString() hiển thị đầy đủ thông tin',
          () {
        // Arrange
        const statusCode = 404;
        const message = 'Not Found Resource';

        // Act
        const error = HttpStatusError(statusCode, message);

        // Assert
        expect(error.statusCode, equals(404));
        expect(error.message, equals('Not Found Resource'));
        expect(error.toString(),
            equals('HttpStatusError(404): Not Found Resource'));
      });

      test(
          '2. Khởi tạo với statusCode không có message, toString() hiển thị mã trạng thái',
          () {
        // Arrange & Act
        const error = HttpStatusError(500);

        // Assert
        expect(error.statusCode, equals(500));
        expect(error.message, isNull);
        expect(error.toString(), equals('HttpStatusError(500)'));
      });

      test('3. Khởi tạo với message rỗng, toString() hiển thị mã trạng thái',
          () {
        // Arrange & Act
        const error = HttpStatusError(400, '');

        // Assert
        expect(error.statusCode, equals(400));
        expect(error.message, isEmpty);
        expect(error.toString(), equals('HttpStatusError(400)'));
      });
    });

    group('CacheStorageError', () {
      test('1. Khởi tạo chỉ với message, toString() định dạng chính xác', () {
        // Arrange & Act
        const error = CacheStorageError('Không thể ghi file bộ nhớ đệm');

        // Assert
        expect(error.message, equals('Không thể ghi file bộ nhớ đệm'));
        expect(error.cause, isNull);
        expect(error.toString(),
            equals('CacheStorageError: Không thể ghi file bộ nhớ đệm'));
      });

      test(
          '2. Khởi tạo với message và cause, toString() chứa nguyên nhân gốc rễ',
          () {
        // Arrange
        final rootCause = Exception('Disk Full OS Error 28');

        // Act
        final error = CacheStorageError('Lỗi I/O ổ đĩa', rootCause);

        // Assert
        expect(error.message, equals('Lỗi I/O ổ đĩa'));
        expect(error.cause, equals(rootCause));
        expect(
            error.toString(),
            contains(
                'CacheStorageError: Lỗi I/O ổ đĩa (Cause: Exception: Disk Full OS Error 28)'));
      });
    });
  });
}
