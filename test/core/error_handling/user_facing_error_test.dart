import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-401: UserFacingError Unit Tests', () {
    test('1. Khởi tạo UserFacingError đầy đủ thuộc tính bất biến', () {
      // Arrange & Act
      const error = UserFacingError(
        message: 'Không thể kết nối máy chủ',
        canRetry: true,
        severity: Severity.warning,
      );

      // Assert
      expect(error.message, equals('Không thể kết nối máy chủ'));
      expect(error.canRetry, isTrue);
      expect(error.severity, equals(Severity.warning));
    });

    test('2. So sánh equality (==) và hashCode chính xác giữa các instances',
        () {
      // Arrange
      const error1 = UserFacingError(
        message: 'Lỗi xác thực',
        canRetry: false,
        severity: Severity.error,
      );
      const error2 = UserFacingError(
        message: 'Lỗi xác thực',
        canRetry: false,
        severity: Severity.error,
      );
      const errorDiff = UserFacingError(
        message: 'Lỗi khác',
        canRetry: false,
        severity: Severity.error,
      );

      // Assert
      expect(error1 == error2, isTrue);
      expect(error1.hashCode, equals(error2.hashCode));
      expect(error1 == errorDiff, isFalse);
    });

    test('3. toString() in ra định dạng rõ ràng cho việc debug', () {
      // Arrange
      const error = UserFacingError(
        message: 'Dữ liệu hỏng',
        canRetry: false,
        severity: Severity.critical,
      );

      // Act & Assert
      expect(
        error.toString(),
        equals(
            'UserFacingError(severity: critical, canRetry: false, message: "Dữ liệu hỏng")'),
      );
    });
  });
}
