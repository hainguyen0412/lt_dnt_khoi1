import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-103: TransactionDraft Entity Tests', () {
    final now = DateTime(2026, 10, 14, 15, 0);

    test('1. ValidatableMixin trên TransactionDraft hoạt động chuẩn (R3)', () {
      final validDraft = TransactionDraft(
        type: TransactionType.expense,
        title: 'Mua bánh mì',
        amount: const Money(20000),
        category: Category.food,
        date: now,
      );

      expect(validDraft.isValid, isTrue);
      expect(validDraft.firstError, isNull);
      expect(validDraft.ensureValid(), isA<Success<void>>());

      final invalidDraft = validDraft.copyWith(
        amount: const Money.zero(),
      );

      expect(invalidDraft.isValid, isFalse);
      expect(invalidDraft.firstError?.field, equals('amount'));

      final result = invalidDraft.ensureValid();
      expect(result, isA<Failure<void>>());
      final failure = result as Failure<void>;
      expect(failure.error, isA<ValidationException>());
    });

    test('2. toTransaction chuyển đổi chính xác sang Transaction hoàn chỉnh',
        () {
      final draft = TransactionDraft(
        type: TransactionType.income,
        title: 'Bán đồ cũ',
        amount: const Money(300000),
        category: Category.other,
        date: now,
        note: 'Bán bàn phím cơ',
      );

      final tx = draft.toTransaction(
        id: 'new-id-999',
        now: now,
      );

      expect(tx.id, equals('new-id-999'));
      expect(tx.type, equals(TransactionType.income));
      expect(tx.title, equals('Bán đồ cũ'));
      expect(tx.amount.amount, equals(300000));
      expect(tx.category, equals(Category.other));
      expect(tx.date, equals(now));
      expect(tx.note, equals('Bán bàn phím cơ'));
      expect(tx.createdAt, equals(now));
      expect(tx.updatedAt, isNull);
    });

    test('3. copyWith và so sánh bằng nhau (==)', () {
      final d1 = TransactionDraft(
        type: TransactionType.expense,
        title: 'Xem phim',
        amount: const Money(150000),
        category: Category.entertainment,
        date: now,
      );

      final d2 = d1.copyWith();
      final d3 = d1.copyWith(title: 'Xem kịch');

      expect(d1 == d2, isTrue);
      expect(d1.hashCode == d2.hashCode, isTrue);
      expect(d1 == d3, isFalse);
    });
  });
}
