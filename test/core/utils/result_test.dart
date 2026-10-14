import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-101: Result<T> Tests', () {
    const testException = NetworkException(message: 'Connection failed');

    test('1. Success giữ data, isSuccess = true, isFailure = false', () {
      const result = Success<int>(100);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, equals(100));
      expect(result.toString(), equals('Success(100)'));
    });

    test('2. Failure giữ error, isSuccess = false, isFailure = true', () {
      const result = Failure<int>(testException);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.error, equals(testException));
      expect(identical(result.error, testException), isTrue);
      expect(
          result.toString(),
          contains(
              'Failure(NetworkException(NETWORK_ERROR): Connection failed)'));
    });

    test('3. fold: thực thi nhánh onSuccess khi là Success', () {
      const Result<int> result = Success(42);

      final output = result.fold(
        (data) => 'Value: $data',
        (error) => 'Error: ${error.message}',
      );

      expect(output, equals('Value: 42'));
    });

    test('4. fold: thực thi nhánh onFailure khi là Failure', () {
      const Result<int> result = Failure(testException);

      final output = result.fold(
        (data) => 'Value: $data',
        (error) => 'Error: ${error.message}',
      );

      expect(output, equals('Error: Connection failed'));
    });

    test('5. map: đổi kiểu dữ liệu thành công với Success<T>', () {
      const Result<int> result = Success(500);

      final mapped = result.map((data) => 'Amount: $data VND');

      expect(mapped, isA<Success<String>>());
      expect((mapped as Success<String>).data, equals('Amount: 500 VND'));
    });

    test('6. map: giữ nguyên đối tượng error gốc (identical) khi là Failure<T>',
        () {
      const Result<int> result = Failure(testException);

      final mapped = result.map((data) => 'Amount: $data VND');

      expect(mapped, isA<Failure<String>>());
      final failure = mapped as Failure<String>;
      expect(identical(failure.error, testException), isTrue);
    });

    test('7. getOrElse: trả về data khi là Success', () {
      const Result<int> result = Success(999);

      final value = result.getOrElse((error) => 0);

      expect(value, equals(999));
    });

    test('8. getOrElse: trả về giá trị fallback khi là Failure', () {
      const Result<int> result = Failure(testException);

      final value = result.getOrElse((error) => -1);

      expect(value, equals(-1));
    });

    test(
        '9. Hỗ trợ Result<void> cho các tác vụ không trả về dữ liệu (như delete)',
        () {
      const Result<void> successVoid = Success(null);
      const Result<void> failureVoid = Failure(testException);

      expect(successVoid.isSuccess, isTrue);
      expect(failureVoid.isFailure, isTrue);

      final executed = successVoid.fold(
        (_) => 'Deleted successfully',
        (err) => 'Failed to delete',
      );
      expect(executed, equals('Deleted successfully'));
    });

    test('10. Exhaustive pattern matching với switch trên sealed class Result',
        () {
      Result<String> check(bool pass) =>
          pass ? const Success('OK') : const Failure(testException);

      String handle(Result<String> res) {
        return switch (res) {
          Success(data: final val) => 'SUCCESS: $val',
          Failure(error: final err) => 'FAILURE: ${err.code}',
        };
      }

      expect(handle(check(true)), equals('SUCCESS: OK'));
      expect(handle(check(false)), equals('FAILURE: NETWORK_ERROR'));
    });
  });
}
