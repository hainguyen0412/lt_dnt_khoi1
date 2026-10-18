import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-103: Transaction Entity Tests', () {
    final now = DateTime(2026, 10, 14, 10, 0);

    test('1. Named constructor Transaction.income gán đúng type income (R1)',
        () {
      final tx = Transaction.income(
        id: 'tx-1',
        title: 'Nhận lương tháng 10',
        amount: const Money(15000000),
        category: Category.salary,
        date: now,
        createdAt: now,
      );

      expect(tx.type, equals(TransactionType.income));
      expect(tx.id, equals('tx-1'));
      expect(tx.amount.amount, equals(15000000));
      expect(tx.category, equals(Category.salary));
      expect(tx.note, isNull);
    });

    test('2. Named constructor Transaction.expense gán đúng type expense (R1)',
        () {
      final tx = Transaction.expense(
        id: 'tx-2',
        title: 'Tiền điện nước',
        amount: const Money(850000),
        category: Category.bills,
        date: now,
        note: 'Hóa đơn tháng 9',
        createdAt: now,
      );

      expect(tx.type, equals(TransactionType.expense));
      expect(tx.id, equals('tx-2'));
      expect(tx.note, equals('Hóa đơn tháng 9'));
    });

    test('3. copyWith tạo bản sao chính xác và bảo toàn các trường không đổi',
        () {
      final original = Transaction.expense(
        id: 'tx-3',
        title: 'Ăn tối',
        amount: const Money(120000),
        category: Category.food,
        date: now,
        createdAt: now,
      );

      final updated = original.copyWith(
        title: 'Ăn tối cùng bạn bè',
        amount: const Money(200000),
        updatedAt: now.add(const Duration(hours: 1)),
      );

      expect(updated.id, equals('tx-3'));
      expect(updated.title, equals('Ăn tối cùng bạn bè'));
      expect(updated.amount.amount, equals(200000));
      expect(updated.category, equals(Category.food));
      expect(updated.updatedAt, equals(now.add(const Duration(hours: 1))));
    });

    test('4. Viết tay toán tử == và hashCode (không dùng Equatable)', () {
      final tx1 = Transaction.income(
        id: 'tx-4',
        title: 'Thưởng KPI',
        amount: const Money(2000000),
        category: Category.salary,
        date: now,
        createdAt: now,
      );

      final tx2 = Transaction.income(
        id: 'tx-4',
        title: 'Thưởng KPI',
        amount: const Money(2000000),
        category: Category.salary,
        date: now,
        createdAt: now,
      );

      final tx3 = tx1.copyWith(id: 'tx-different');

      expect(tx1 == tx2, isTrue);
      expect(tx1.hashCode == tx2.hashCode, isTrue);
      expect(tx1 == tx3, isFalse);
    });

    test('5. TimestampMixin: lastModified và isNewerThan (R3)', () {
      final createdTime = DateTime(2026, 10, 10, 8, 0);
      final updatedTime = DateTime(2026, 10, 10, 12, 0);

      final txWithoutUpdate = Transaction.expense(
        id: 'tx-5',
        title: 'Trà sữa',
        amount: const Money(45000),
        category: Category.food,
        date: createdTime,
        createdAt: createdTime,
      );
      expect(txWithoutUpdate.lastModified, equals(createdTime));

      final txWithUpdate = txWithoutUpdate.copyWith(
        updatedAt: updatedTime,
      );
      expect(txWithUpdate.lastModified, equals(updatedTime));
      expect(txWithUpdate.isNewerThan(txWithoutUpdate), isTrue);
    });

    test('6. ValidatableMixin: isValid và ensureValid trên Transaction (R3)',
        () {
      final validTx = Transaction.expense(
        id: 'tx-6',
        title: 'Xăng xe',
        amount: const Money(50000),
        category: Category.transport,
        date: now,
        createdAt: now,
      );
      expect(validTx.isValid, isTrue);
      expect(validTx.ensureValid(), isA<Success<void>>());

      final invalidTx = validTx.copyWith(
        title: '   ', // Tiêu đề rỗng
      );
      expect(invalidTx.isValid, isFalse);

      final result = invalidTx.ensureValid();
      expect(result, isA<Failure<void>>());
      final failure = result as Failure<void>;
      expect(failure.error, isA<ValidationException>());
      expect((failure.error as ValidationException).field, equals('title'));
    });
  });
}
