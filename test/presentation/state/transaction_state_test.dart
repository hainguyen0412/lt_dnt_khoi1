import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_summary.dart';
import 'package:expense_tracker/presentation/state/transaction_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-401: TransactionListState Unit Tests', () {
    final now = DateTime(2026, 10, 15, 10, 0);

    final tx1 = Transaction.income(
      id: 'tx-1',
      title: 'Lương',
      amount: const Money(10000000),
      category: Category.salary,
      date: now,
      createdAt: now,
    );

    final tx2 = Transaction.expense(
      id: 'tx-2',
      title: 'Cơm',
      amount: const Money(50000),
      category: Category.food,
      date: now,
      createdAt: now,
    );

    const summary = TransactionSummary(
      totalIncome: Money(10000000),
      totalExpense: Money(50000),
    );

    test(
        '1. TransactionListInitial và TransactionListLoading khởi tạo bình thường',
        () {
      const initial = TransactionListInitial();
      const loading = TransactionListLoading();
      const empty = TransactionListEmpty();

      expect(initial, isA<TransactionListState>());
      expect(loading, isA<TransactionListState>());
      expect(empty, isA<TransactionListState>());
    });

    test('2. TransactionListLoaded: so sánh equality và hashCode chuẩn xác',
        () {
      final state1 = TransactionListLoaded(items: [tx1, tx2], summary: summary);
      final state2 = TransactionListLoaded(items: [tx1, tx2], summary: summary);
      final stateDiff = TransactionListLoaded(items: [tx1], summary: summary);

      expect(state1 == state2, isTrue);
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1 == stateDiff, isFalse);
    });

    test(
        '3. TransactionListError: so sánh equality và hashCode bảo toàn previousItems',
        () {
      const userError = UserFacingError(
        message: 'Lỗi mạng',
        canRetry: true,
        severity: Severity.warning,
      );

      final state1 = TransactionListError(
        error: userError,
        previousItems: [tx1],
        previousSummary: summary,
      );
      final state2 = TransactionListError(
        error: userError,
        previousItems: [tx1],
        previousSummary: summary,
      );
      const stateNoPrevious = TransactionListError(
        error: userError,
      );

      expect(state1 == state2, isTrue);
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1 == stateNoPrevious, isFalse);
    });
  });
}
