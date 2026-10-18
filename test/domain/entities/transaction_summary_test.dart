import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-103: TransactionSummary Entity Tests', () {
    test('1. balance = totalIncome - totalExpense (dương khi thu > chi)', () {
      const summary = TransactionSummary(
        totalIncome: Money(10000000),
        totalExpense: Money(6000000),
      );

      expect(summary.totalIncome.amount, equals(10000000));
      expect(summary.totalExpense.amount, equals(6000000));
      expect(summary.balance.amount, equals(4000000));
      expect(summary.balance.isPositive, isTrue);
    });

    test('2. balance có thể mang giá trị âm khi chi > thu', () {
      const summary = TransactionSummary(
        totalIncome: Money(3000000),
        totalExpense: Money(5000000),
      );

      expect(summary.balance.amount, equals(-2000000));
      expect(summary.balance.isPositive, isFalse);
    });

    test('3. balance bằng 0 khi thu = chi', () {
      const summary = TransactionSummary(
        totalIncome: Money(500000),
        totalExpense: Money(500000),
      );

      expect(summary.balance.amount, equals(0));
    });

    test('4. So sánh bằng nhau (==) và hashCode', () {
      const s1 = TransactionSummary(
        totalIncome: Money(1000),
        totalExpense: Money(500),
      );
      const s2 = TransactionSummary(
        totalIncome: Money(1000),
        totalExpense: Money(500),
      );
      const s3 = TransactionSummary(
        totalIncome: Money(2000),
        totalExpense: Money(500),
      );

      expect(s1 == s2, isTrue);
      expect(s1.hashCode == s2.hashCode, isTrue);
      expect(s1 == s3, isFalse);
    });
  });
}
