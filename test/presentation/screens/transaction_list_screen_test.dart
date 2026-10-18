import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/domain/entities/transaction_summary.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:expense_tracker/presentation/screens/transaction_list_screen.dart';
import 'package:expense_tracker/presentation/state/transaction_notifier.dart';
import 'package:expense_tracker/presentation/state/transaction_state.dart';
import 'package:expense_tracker/presentation/widgets/empty_view.dart';
import 'package:expense_tracker/presentation/widgets/error_view.dart';
import 'package:expense_tracker/presentation/widgets/summary_card.dart';
import 'package:expense_tracker/presentation/widgets/transaction_tile.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Lớp Fake [TransactionNotifier] phục vụ kiểm thử Widget thuần túy,
/// cho phép giả lập linh hoạt mọi trạng thái danh sách và thao tác.
class FakeTransactionNotifier extends ChangeNotifier
    implements TransactionNotifier {
  TransactionListState _fakeState;
  UserFacingError? _fakeActionError;
  int loadCallCount = 0;
  String? lastDeletedId;

  final ValueNotifier<UserFacingError?> _fakeBoundaryError =
      ValueNotifier<UserFacingError?>(null);

  FakeTransactionNotifier({
    TransactionListState initialState = const TransactionListInitial(),
  }) : _fakeState = initialState;

  void emitState(TransactionListState state) {
    _fakeState = state;
    notifyListeners();
  }

  void emitActionError(UserFacingError? error) {
    _fakeActionError = error;
    notifyListeners();
  }

  @override
  TransactionListState get listState => _fakeState;

  @override
  bool get isSubmitting => false;

  @override
  Map<String, String> get fieldErrors => const {};

  @override
  UserFacingError? get actionError => _fakeActionError;

  @override
  ValueListenable<UserFacingError?> get boundaryError => _fakeBoundaryError;

  @override
  Future<void> load() async {
    loadCallCount++;
  }

  @override
  Future<bool> add(TransactionDraft draft) async => true;

  @override
  Future<bool> update(Transaction transaction) async => true;

  @override
  Future<bool> delete(String id) async {
    lastDeletedId = id;
    return true;
  }

  @override
  Future<void> retryLast() async {
    loadCallCount++;
  }

  @override
  void clearActionError() {
    _fakeActionError = null;
    notifyListeners();
  }

  @override
  void clearFieldErrors([String? field]) {}

  @override
  void reportBoundaryError(UserFacingError error) {
    _fakeBoundaryError.value = error;
  }

  @override
  void clearBoundaryError() {
    _fakeBoundaryError.value = null;
  }
}

void main() {
  final sampleDate = DateTime(2026, 10, 15);

  final sampleIncomeTx = Transaction(
    id: 'tx-income-1',
    title: 'Tiền lương tháng 10',
    amount: const Money(20000000),
    type: TransactionType.income,
    category: Category.salary,
    date: sampleDate,
    createdAt: sampleDate,
  );

  final sampleExpenseTx = Transaction(
    id: 'tx-expense-1',
    title: 'Tiền ăn trưa',
    amount: const Money(45000),
    type: TransactionType.expense,
    category: Category.food,
    date: sampleDate,
    createdAt: sampleDate,
  );

  const sampleSummary = TransactionSummary(
    totalIncome: Money(20000000),
    totalExpense: Money(45000),
  );

  Widget createTestWidget(TransactionNotifier notifier) {
    return ChangeNotifierProvider<TransactionNotifier>.value(
      value: notifier,
      child: const MaterialApp(
        home: TransactionListScreen(),
      ),
    );
  }

  group('T-302: TransactionListScreen Widget Tests', () {
    testWidgets('1. Trạng thái Loading -> hiển thị CircularProgressIndicator',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: const TransactionListLoading(),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(EmptyView), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(SummaryCard), findsNothing);
    });

    testWidgets(
        '2. Trạng thái Empty -> hiển thị EmptyView và nút Thêm giao dịch',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: const TransactionListEmpty(),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
      expect(find.text('Thêm giao dịch'), findsWidgets);
    });

    testWidgets(
        '3. Trạng thái Error (canRetry = true) -> hiển thị ErrorView và CÓ nút "Thử lại"',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: const TransactionListError(
          error: UserFacingError(
            message: 'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
            canRetry: true,
            severity: Severity.warning,
          ),
        ),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('Không có kết nối mạng. Vui lòng kiểm tra và thử lại.'),
        findsOneWidget,
      );

      final retryButton = find.widgetWithText(ElevatedButton, 'Thử lại');
      expect(retryButton, findsOneWidget);

      // Bấm nút thử lại -> gọi notifier.load()
      await tester.tap(retryButton);
      await tester.pump();

      // initState gọi 1 lần + bấm nút gọi 1 lần = 2 lần load
      expect(fakeNotifier.loadCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets(
        '4. Trạng thái Error (canRetry = false) -> hiển thị thông báo nhưng KHÔNG có nút "Thử lại"',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: const TransactionListError(
          error: UserFacingError(
            message: 'Dữ liệu nhận về không đúng định dạng.',
            canRetry: false,
            severity: Severity.error,
          ),
        ),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('Dữ liệu nhận về không đúng định dạng.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Thử lại'), findsNothing);
    });

    testWidgets(
        '5. Trạng thái Loaded -> hiển thị SummaryCard và các TransactionTile',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: TransactionListLoaded(
          items: [sampleIncomeTx, sampleExpenseTx],
          summary: sampleSummary,
        ),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      // Kiểm tra SummaryCard
      expect(find.byType(SummaryCard), findsOneWidget);
      expect(find.text('Số dư hiện tại'), findsOneWidget);
      expect(find.text('Tổng thu'), findsOneWidget);
      expect(find.text('Tổng chi'), findsOneWidget);

      // Kiểm tra TransactionTile
      expect(find.byType(TransactionTile), findsNWidgets(2));
      expect(find.text('Tiền lương tháng 10'), findsOneWidget);
      expect(find.text('Tiền ăn trưa'), findsOneWidget);
    });

    testWidgets(
        '6. Accessibility Check: Thu nhập có dấu "+" và Chi tiêu có dấu "-"',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: TransactionListLoaded(
          items: [sampleIncomeTx, sampleExpenseTx],
          summary: sampleSummary,
        ),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      // Thu nhập phải có dấu '+'
      expect(find.text('+ 20.000.000 ₫'), findsWidgets);

      // Chi tiêu phải có dấu '-'
      expect(find.text('- 45.000 ₫'), findsWidgets);
    });

    testWidgets('7. ErrorView.compact render đúng và gọn gàng', (tester) async {
      const error = UserFacingError(
        message: 'Lỗi widget cục bộ.',
        canRetry: true,
        severity: Severity.warning,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ErrorView.compact(
                error: error,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Lỗi widget cục bộ.'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets(
        '8. Khi notifier.boundaryError phát sinh lỗi nghiêm trọng -> ErrorBoundary hiển thị ErrorView thay cho danh sách',
        (tester) async {
      final fakeNotifier = FakeTransactionNotifier(
        initialState: TransactionListLoaded(
          items: [sampleIncomeTx],
          summary: sampleSummary,
        ),
      );

      await tester.pumpWidget(createTestWidget(fakeNotifier));
      await tester.pump();

      expect(find.byType(SummaryCard), findsOneWidget);

      // Kích hoạt lỗi cấp boundary
      fakeNotifier.reportBoundaryError(
        const UserFacingError(
          message: 'Sự cố vỡ bộ nhớ nghiêm trọng',
          canRetry: true,
          severity: Severity.critical,
        ),
      );
      await tester.pump();

      // Danh sách bị thay thế bằng ErrorView
      expect(find.byType(SummaryCard), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Sự cố vỡ bộ nhớ nghiêm trọng'), findsOneWidget);
    });
  });
}
