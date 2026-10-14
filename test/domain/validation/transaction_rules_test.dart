import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/validation/transaction_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-103: TransactionRules Validation Tests', () {
    final fixedNow = DateTime(2026, 10, 14, 12, 0, 0);

    test('1. Hợp lệ hoàn toàn -> trả về danh sách lỗi rỗng', () {
      final errors = TransactionRules.validate(
        title: 'Cơm trưa',
        amount: const Money(35000),
        date: fixedNow,
        now: fixedNow,
      );

      expect(errors, isEmpty);
    });

    test('2. Quy tắc title: Rỗng hoặc toàn khoảng trắng -> báo lỗi field title',
        () {
      final errorsEmpty = TransactionRules.validate(
        title: '',
        amount: const Money(50000),
        date: fixedNow,
        now: fixedNow,
      );
      expect(errorsEmpty.length, equals(1));
      expect(errorsEmpty.first.field, equals('title'));
      expect(errorsEmpty.first.message,
          equals('Tiêu đề giao dịch không được để trống.'));

      final errorsWhitespace = TransactionRules.validate(
        title: '   ',
        amount: const Money(50000),
        date: fixedNow,
        now: fixedNow,
      );
      expect(errorsWhitespace.length, equals(1));
      expect(errorsWhitespace.first.field, equals('title'));
    });

    test('3. Quy tắc amount: <= 0 (bằng 0 hoặc âm) -> báo lỗi field amount',
        () {
      final errorsZero = TransactionRules.validate(
        title: 'Tiền xăng',
        amount: const Money.zero(),
        date: fixedNow,
        now: fixedNow,
      );
      expect(errorsZero.length, equals(1));
      expect(errorsZero.first.field, equals('amount'));
      expect(errorsZero.first.message,
          equals('Số tiền phải là số nguyên dương lớn hơn 0.'));

      final errorsNegative = TransactionRules.validate(
        title: 'Tiền xăng',
        amount: const Money(-20000),
        date: fixedNow,
        now: fixedNow,
      );
      expect(errorsNegative.length, equals(1));
      expect(errorsNegative.first.field, equals('amount'));
    });

    test('4. Quy tắc date: Trước năm 2000 -> báo lỗi field date', () {
      final errorsBefore2000 = TransactionRules.validate(
        title: 'Mua sách cũ',
        amount: const Money(10000),
        date: DateTime(1999, 12, 31),
        now: fixedNow,
      );
      expect(errorsBefore2000.length, equals(1));
      expect(errorsBefore2000.first.field, equals('date'));
      expect(errorsBefore2000.first.message,
          equals('Ngày giao dịch không hợp lệ (từ năm 2000 đến hiện tại).'));
    });

    test('5. Quy tắc date: Sau now + 1 ngày -> báo lỗi field date', () {
      final exactLimit = fixedNow.add(const Duration(days: 1));
      final afterLimit = exactLimit.add(const Duration(seconds: 1));

      // Đúng mốc now + 1 ngày: Vẫn hợp lệ
      final errorsAtLimit = TransactionRules.validate(
        title: 'Hẹn trả tiền',
        amount: const Money(50000),
        date: exactLimit,
        now: fixedNow,
      );
      expect(errorsAtLimit, isEmpty);

      // Sau mốc now + 1 ngày: Báo lỗi
      final errorsAfterLimit = TransactionRules.validate(
        title: 'Hẹn trả tiền',
        amount: const Money(50000),
        date: afterLimit,
        now: fixedNow,
      );
      expect(errorsAfterLimit.length, equals(1));
      expect(errorsAfterLimit.first.field, equals('date'));
    });

    test('6. Thứ tự lỗi cố định: title -> amount -> date khi cả 3 đều sai', () {
      final errors = TransactionRules.validate(
        title: '  ',
        amount: const Money(-1),
        date: DateTime(1990, 1, 1),
        now: fixedNow,
      );

      expect(errors.length, equals(3));
      expect(errors[0].field, equals('title'));
      expect(errors[1].field, equals('amount'));
      expect(errors[2].field, equals('date'));
    });
  });
}
