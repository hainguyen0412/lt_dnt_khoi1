import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:expense_tracker/presentation/screens/transaction_form_screen.dart';
import 'package:expense_tracker/presentation/state/transaction_notifier.dart';
import 'package:expense_tracker/presentation/state/transaction_state.dart';
import 'package:expense_tracker/presentation/widgets/error_view.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeFormTransactionNotifier extends ChangeNotifier
    implements TransactionNotifier {
  Map<String, String> _fakeFieldErrors = {};
  UserFacingError? _fakeActionError;
  bool _fakeIsSubmitting = false;
  final ValueNotifier<UserFacingError?> _fakeBoundaryError =
      ValueNotifier<UserFacingError?>(null);

  int addCallCount = 0;
  int retryCallCount = 0;
  int deleteCallCount = 0;
  int clearFieldErrorsCallCount = 0;
  String? lastClearedField;
  TransactionDraft? lastDraft;

  bool shouldFailWithValidation = false;
  bool shouldFailWithServerError = false;

  void setIsSubmitting(bool value) {
    _fakeIsSubmitting = value;
    notifyListeners();
  }

  void setFieldErrors(Map<String, String> errors) {
    _fakeFieldErrors = Map.from(errors);
    notifyListeners();
  }

  void setActionError(UserFacingError? error) {
    _fakeActionError = error;
    notifyListeners();
  }

  @override
  Map<String, String> get fieldErrors => _fakeFieldErrors;

  @override
  UserFacingError? get actionError => _fakeActionError;

  @override
  bool get isSubmitting => _fakeIsSubmitting;

  @override
  ValueListenable<UserFacingError?> get boundaryError => _fakeBoundaryError;

  @override
  TransactionListState get listState => const TransactionListInitial();

  @override
  Future<void> load() async {}

  @override
  Future<bool> add(TransactionDraft draft) async {
    addCallCount++;
    lastDraft = draft;

    if (shouldFailWithValidation) {
      if (draft.title.isEmpty) {
        _fakeFieldErrors['title'] = 'Tiêu đề không được để trống.';
      }
      if (draft.amount.amount <= 0) {
        _fakeFieldErrors['amount'] = 'Số tiền giao dịch phải lớn hơn 0.';
      }
      notifyListeners();
      return false;
    }

    if (shouldFailWithServerError) {
      _fakeActionError = const UserFacingError(
        message: 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
        canRetry: true,
        severity: Severity.error,
      );
      notifyListeners();
      return false;
    }

    return true;
  }

  @override
  Future<bool> update(Transaction transaction) async => true;

  @override
  Future<bool> delete(String id) async {
    deleteCallCount++;
    return true;
  }

  @override
  Future<void> retryLast() async {
    retryCallCount++;
  }

  @override
  void clearActionError() {
    _fakeActionError = null;
    notifyListeners();
  }

  @override
  void clearFieldErrors([String? field]) {
    clearFieldErrorsCallCount++;
    lastClearedField = field;
    if (field != null) {
      _fakeFieldErrors.remove(field);
    } else {
      _fakeFieldErrors.clear();
    }
    notifyListeners();
  }

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

  final sampleTx = Transaction(
    id: 'tx-test-01',
    title: 'Tiền thưởng dự án',
    amount: const Money(5000000),
    type: TransactionType.income,
    category: Category.salary,
    date: sampleDate,
    createdAt: sampleDate,
    note: 'Thưởng hoàn thành Sprint 3',
  );

  Widget createTestWidget(
    TransactionNotifier notifier, {
    Transaction? initialTransaction,
  }) {
    return ChangeNotifierProvider<TransactionNotifier>.value(
      value: notifier,
      child: MaterialApp(
        home: TransactionFormScreen(
          initialTransaction: initialTransaction,
        ),
      ),
    );
  }

  group('T-303: TransactionFormScreen Widget Tests', () {
    testWidgets(
        '1. Nhập số âm -> thông báo lỗi hiện dưới ô số tiền từ Domain Validation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier()
        ..shouldFailWithValidation = true;

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Nhập tiêu đề hợp lệ
      final titleField = find.widgetWithText(TextField, 'Tiêu đề giao dịch *');
      await tester.enterText(titleField, 'Mua cà phê');

      // Nhập số tiền âm (ví dụ: -50000)
      final amountField = find.widgetWithText(TextField, 'Số tiền (VND) *');
      await tester.enterText(amountField, '-50000');

      // Nhấn Lưu
      final saveButton = find.byType(FilledButton);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Kiểm tra lỗi dưới ô số tiền
      expect(
        find.text('Số tiền giao dịch phải lớn hơn 0.'),
        findsOneWidget,
      );
      expect(notifier.addCallCount, equals(1));
      expect(notifier.lastDraft?.amount.amount, equals(-50000));
    });

    testWidgets(
        '2. Tiêu đề rỗng -> thông báo lỗi hiện dưới ô tiêu đề từ Domain Validation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier()
        ..shouldFailWithValidation = true;

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Để trống tiêu đề, nhập số tiền dương
      final amountField = find.widgetWithText(TextField, 'Số tiền (VND) *');
      await tester.enterText(amountField, '50000');

      // Nhấn Lưu
      final saveButton = find.byType(FilledButton);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Kiểm tra lỗi xuất hiện dưới ô tiêu đề
      expect(
        find.text('Tiêu đề không được để trống.'),
        findsOneWidget,
      );
      expect(notifier.addCallCount, equals(1));
    });

    testWidgets(
        '3. Người dùng sửa lại ô nhập -> gọi clearFieldErrors của trường đó',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier();

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Giả lập lỗi xuất hiện sau khi mở form
      notifier.setFieldErrors({'title': 'Tiêu đề không được để trống.'});
      await tester.pump();

      expect(find.text('Tiêu đề không được để trống.'), findsOneWidget);

      // Gõ vào ô tiêu đề
      final titleField = find.widgetWithText(TextField, 'Tiêu đề giao dịch *');
      await tester.enterText(titleField, 'Ăn trưa');
      await tester.pumpAndSettle();

      expect(notifier.lastClearedField, equals('title'));
      expect(find.text('Tiêu đề không được để trống.'), findsNothing);
    });

    testWidgets(
        '4. Nút Lưu bị vô hiệu hóa khi notifier.isSubmitting == true (Chống bấm đúp)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier()..setIsSubmitting(true);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pump();

      // Tìm nút FilledButton
      final filledButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(filledButton.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        '5. Thất bại do lỗi Server -> SnackBar xuất hiện kèm nút "Thử lại"',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier()
        ..shouldFailWithServerError = true;

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Nhập dữ liệu
      await tester.enterText(
        find.widgetWithText(TextField, 'Tiêu đề giao dịch *'),
        'Đổ xăng',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền (VND) *'),
        '100000',
      );

      // Bấm Lưu
      final saveButton = find.byType(FilledButton);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Kiểm tra SnackBar xuất hiện
      expect(
        find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
        findsOneWidget,
      );

      final retryAction = find.text('Thử lại');
      expect(retryAction, findsOneWidget);

      // Nhấn Thử lại trên SnackBar
      await tester.tap(retryAction);
      await tester.pump();

      expect(notifier.retryCallCount, equals(1));
    });

    testWidgets('6. Chế độ Chỉnh sửa -> nạp sẵn dữ liệu cũ và có nút Xóa',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier();

      await tester.pumpWidget(
        createTestWidget(notifier, initialTransaction: sampleTx),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề màn hình
      expect(find.text('Sửa giao dịch'), findsOneWidget);
      expect(find.text('Tiền thưởng dự án'), findsOneWidget);
      expect(find.text('5000000'), findsOneWidget);
      expect(find.text('Thưởng hoàn thành Sprint 3'), findsOneWidget);

      // Kiểm tra nút Xóa trên AppBar
      final deleteButton = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButton, findsOneWidget);

      // Nhấn nút Xóa -> mở dialog xác nhận
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);
      expect(
        find.text(
          'Bạn có chắc chắn muốn xóa giao dịch "Tiền thưởng dự án" không?',
        ),
        findsOneWidget,
      );

      // Nhấn Xóa trong Dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(notifier.deleteCallCount, equals(1));
    });

    testWidgets(
        '7. Khi notifier.boundaryError có lỗi nghiêm trọng -> ErrorBoundary thay thế Form bằng ErrorView',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = FakeFormTransactionNotifier();

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Form ban đầu hiển thị ô nhập tiêu đề
      expect(find.text('Tiêu đề giao dịch *'), findsOneWidget);

      // Kích hoạt lỗi cấp boundary
      notifier.reportBoundaryError(
        const UserFacingError(
          message: 'Lỗi bộ nhớ form nghiêm trọng',
          canRetry: true,
          severity: Severity.critical,
        ),
      );
      await tester.pump();

      // Form bị ẩn, ErrorView xuất hiện
      expect(find.text('Tiêu đề giao dịch *'), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Lỗi bộ nhớ form nghiêm trọng'), findsOneWidget);
    });
  });
}
