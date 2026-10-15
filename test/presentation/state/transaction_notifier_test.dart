import 'package:expense_tracker/core/error_handling/error_handler.dart';
import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/domain/entities/transaction_summary.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:expense_tracker/domain/usecases/add_transaction.dart';
import 'package:expense_tracker/domain/usecases/delete_transaction.dart';
import 'package:expense_tracker/domain/usecases/get_summary.dart';
import 'package:expense_tracker/domain/usecases/get_transaction_by_id.dart';
import 'package:expense_tracker/domain/usecases/get_transactions.dart';
import 'package:expense_tracker/domain/usecases/update_transaction.dart';
import 'package:expense_tracker/presentation/state/transaction_notifier.dart';
import 'package:expense_tracker/presentation/state/transaction_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// --- MOCK CLASSES DÙNG MOCKTAIL ---
class MockGetTransactions extends Mock implements GetTransactions {}

class MockGetTransactionById extends Mock implements GetTransactionById {}

class MockAddTransaction extends Mock implements AddTransaction {}

class MockUpdateTransaction extends Mock implements UpdateTransaction {}

class MockDeleteTransaction extends Mock implements DeleteTransaction {}

class MockGetSummary extends Mock implements GetSummary {}

class MockErrorHandler extends Mock implements ErrorHandler {}

// --- FAKE TYPES CHO FALLBACK REGISTER ---
class FakeTransactionDraft extends Fake implements TransactionDraft {}

class FakeTransaction extends Fake implements Transaction {}

class FakeStackTrace extends Fake implements StackTrace {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTransactionDraft());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(FakeStackTrace());
    registerFallbackValue(Exception('fallback'));
  });

  late MockGetTransactions mockGetTransactions;
  late MockGetTransactionById mockGetTransactionById;
  late MockAddTransaction mockAddTransaction;
  late MockUpdateTransaction mockUpdateTransaction;
  late MockDeleteTransaction mockDeleteTransaction;
  late MockGetSummary mockGetSummary;
  late MockErrorHandler mockErrorHandler;
  late TransactionNotifier notifier;

  final sampleDate = DateTime(2026, 10, 15);
  final sampleTx = Transaction(
    id: 'tx-001',
    title: 'Cơm trưa văn phòng',
    amount: const Money(45000),
    type: TransactionType.expense,
    category: Category.food,
    date: sampleDate,
    createdAt: sampleDate,
  );

  final sampleDraft = TransactionDraft(
    title: 'Cơm trưa văn phòng',
    amount: const Money(45000),
    type: TransactionType.expense,
    category: Category.food,
    date: sampleDate,
  );

  const sampleSummary = TransactionSummary(
    totalIncome: Money(10000000),
    totalExpense: Money(45000),
  );

  const emptySummary = TransactionSummary(
    totalIncome: Money.zero(),
    totalExpense: Money.zero(),
  );

  const networkUserError = UserFacingError(
    message: 'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
    canRetry: true,
    severity: Severity.warning,
  );

  const serverUserError = UserFacingError(
    message: 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
    canRetry: true,
    severity: Severity.error,
  );

  const validationUserError = UserFacingError(
    message: 'Số tiền giao dịch phải lớn hơn 0.',
    canRetry: false,
    severity: Severity.warning,
  );

  const crashUserError = UserFacingError(
    message: 'Đã xảy ra lỗi không xác định.',
    canRetry: false,
    severity: Severity.critical,
  );

  setUp(() {
    mockGetTransactions = MockGetTransactions();
    mockGetTransactionById = MockGetTransactionById();
    mockAddTransaction = MockAddTransaction();
    mockUpdateTransaction = MockUpdateTransaction();
    mockDeleteTransaction = MockDeleteTransaction();
    mockGetSummary = MockGetSummary();
    mockErrorHandler = MockErrorHandler();

    notifier = TransactionNotifier(
      getTransactions: mockGetTransactions,
      getTransactionById: mockGetTransactionById,
      addTransaction: mockAddTransaction,
      updateTransaction: mockUpdateTransaction,
      deleteTransaction: mockDeleteTransaction,
      getSummary: mockGetSummary,
      errorHandler: mockErrorHandler,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('T-301: TransactionNotifier Unit Tests', () {
    test('1. Trạng thái khởi tạo ban đầu là TransactionListInitial', () {
      expect(notifier.listState, isA<TransactionListInitial>());
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.fieldErrors, isEmpty);
      expect(notifier.actionError, isNull);
      expect(notifier.boundaryError.value, isNull);
    });

    test('2. load() thành công có dữ liệu -> TransactionListLoaded', () async {
      when(() => mockGetTransactions())
          .thenAnswer((_) async => Success([sampleTx]));
      when(() => mockGetSummary())
          .thenAnswer((_) async => const Success(sampleSummary));

      final future = notifier.load();
      // Kiểm tra trạng thái chuyển tiếp Loading
      expect(notifier.listState, isA<TransactionListLoading>());

      await future;

      expect(notifier.listState, isA<TransactionListLoaded>());
      final loaded = notifier.listState as TransactionListLoaded;
      expect(loaded.items, equals([sampleTx]));
      expect(loaded.summary, equals(sampleSummary));
      expect(notifier.isSubmitting, isFalse);
    });

    test('3. load() thành công nhưng rỗng -> TransactionListEmpty', () async {
      when(() => mockGetTransactions())
          .thenAnswer((_) async => const Success(<Transaction>[]));
      when(() => mockGetSummary())
          .thenAnswer((_) async => const Success(emptySummary));

      await notifier.load();

      expect(notifier.listState, isA<TransactionListEmpty>());
    });

    test(
        '4. load() gặp lỗi Network -> TransactionListError kèm UserFacingError và canRetry = true',
        () async {
      const networkEx = NetworkException(message: 'No internet');
      when(() => mockGetTransactions())
          .thenAnswer((_) async => const Failure(networkEx));
      when(() => mockErrorHandler.handle(
            any(),
            any(),
            source: any(named: 'source'),
          )).thenAnswer((_) async => networkUserError);

      await notifier.load();

      expect(notifier.listState, isA<TransactionListError>());
      final errorState = notifier.listState as TransactionListError;
      expect(errorState.error.message,
          equals('Không có kết nối mạng. Vui lòng kiểm tra và thử lại.'));
      expect(errorState.error.canRetry, isTrue);
      expect(errorState.previousItems, isNull);

      verify(() => mockErrorHandler.handle(
            networkEx,
            any(),
            source: 'TransactionNotifier',
          )).called(1);
    });

    test(
        '5. add() gặp lỗi Validation -> đổ vào fieldErrors, không đổi listState, trả về false',
        () async {
      const validationEx = ValidationException(
        field: 'amount',
        message: 'Số tiền giao dịch phải lớn hơn 0.',
      );

      when(() => mockAddTransaction(any()))
          .thenAnswer((_) async => const Failure(validationEx));
      when(() => mockErrorHandler.handle(
            any(),
            any(),
            source: any(named: 'source'),
          )).thenAnswer((_) async => validationUserError);

      final success = await notifier.add(sampleDraft);

      expect(success, isFalse);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.listState, isA<TransactionListInitial>());
      expect(notifier.actionError, isNull);
      expect(notifier.fieldErrors['amount'],
          equals('Số tiền giao dịch phải lớn hơn 0.'));

      // Đảm bảo lỗi validation vẫn đi qua ErrorHandler để ghi log
      verify(() => mockErrorHandler.handle(
            validationEx,
            any(),
            source: 'TransactionNotifier',
          )).called(1);
    });

    test(
        '6. add() gặp lỗi Server -> actionError có giá trị, fieldErrors rỗng, trả về false',
        () async {
      final serverEx = ServerException(
        statusCode: 500,
        message: 'Internal Server Error',
      );

      when(() => mockAddTransaction(any()))
          .thenAnswer((_) async => Failure(serverEx));
      when(() => mockErrorHandler.handle(
            any(),
            any(),
            source: any(named: 'source'),
          )).thenAnswer((_) async => serverUserError);

      final success = await notifier.add(sampleDraft);

      expect(success, isFalse);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.listState, isA<TransactionListInitial>());
      expect(notifier.fieldErrors, isEmpty);
      expect(notifier.actionError, equals(serverUserError));

      verify(() => mockErrorHandler.handle(
            serverEx,
            any(),
            source: 'TransactionNotifier',
          )).called(1);
    });

    test(
        '7. Usecase ném ngoại lệ bất ngờ -> boundaryError nhận lỗi và finally bảo đảm isSubmitting = false (R8)',
        () async {
      final unexpectedCrash = StateError('Cực kỳ bất ngờ: Lỗi bộ nhớ runtime');

      when(() => mockAddTransaction(any())).thenThrow(unexpectedCrash);
      when(() => mockErrorHandler.handle(
            any(),
            any(),
            source: any(named: 'source'),
          )).thenAnswer((_) async => crashUserError);

      final success = await notifier.add(sampleDraft);

      expect(success, isFalse);
      // R8: Khối finally bắt buộc phải đưa isSubmitting về false
      expect(notifier.isSubmitting, isFalse);
      // Kênh boundaryError nhận lỗi để ErrorBoundary (T-304) xử lý
      expect(notifier.boundaryError.value, equals(crashUserError));

      verify(() => mockErrorHandler.handle(
            unexpectedCrash,
            any(),
            source: 'TransactionNotifier',
          )).called(1);
    });

    test(
        '8. retryLast() thực thi lại chính xác hành động gần nhất và tự động xóa boundaryError',
        () async {
      // Giả sử trước đó có boundaryError từ lỗi bất ngờ
      notifier.reportBoundaryError(crashUserError);
      expect(notifier.boundaryError.value, equals(crashUserError));

      // Lần 1: load() lỗi mạng
      const networkEx = NetworkException(message: 'No connection');
      when(() => mockGetTransactions())
          .thenAnswer((_) async => const Failure(networkEx));
      when(() => mockErrorHandler.handle(
            any(),
            any(),
            source: any(named: 'source'),
          )).thenAnswer((_) async => networkUserError);

      await notifier.load();
      expect(notifier.listState, isA<TransactionListError>());

      // Chuẩn bị cho lần retry: mock trả về thành công
      when(() => mockGetTransactions())
          .thenAnswer((_) async => Success([sampleTx]));
      when(() => mockGetSummary())
          .thenAnswer((_) async => const Success(sampleSummary));

      // Gọi retryLast()
      await notifier.retryLast();

      // boundaryError phải được xóa sạch
      expect(notifier.boundaryError.value, isNull);
      // Danh sách được tải lại thành công
      expect(notifier.listState, isA<TransactionListLoaded>());
      verify(() => mockGetTransactions()).called(2);
    });

    test(
        '9. clearFieldErrors() hoạt động linh hoạt: xóa từng trường hoặc xóa toàn bộ',
        () async {
      const valEx1 = ValidationException(field: 'title', message: 'Thiếu tên');
      when(() => mockAddTransaction(any()))
          .thenAnswer((_) async => const Failure(valEx1));
      when(() => mockErrorHandler.handle(any(), any(),
              source: any(named: 'source')))
          .thenAnswer((_) async => const UserFacingError(
                message: 'Thiếu tên',
                canRetry: false,
                severity: Severity.warning,
              ));

      await notifier.add(sampleDraft);
      expect(notifier.fieldErrors['title'], equals('Thiếu tên'));

      // Xóa trường không tồn tại -> không làm ảnh hưởng
      notifier.clearFieldErrors('amount');
      expect(notifier.fieldErrors['title'], equals('Thiếu tên'));

      // Xóa đúng trường 'title'
      notifier.clearFieldErrors('title');
      expect(notifier.fieldErrors, isEmpty);
    });

    test('10. delete() thành công tự động reload danh sách', () async {
      when(() => mockDeleteTransaction('tx-001'))
          .thenAnswer((_) async => const Success(null));
      when(() => mockGetTransactions())
          .thenAnswer((_) async => const Success(<Transaction>[]));
      when(() => mockGetSummary())
          .thenAnswer((_) async => const Success(emptySummary));

      final success = await notifier.delete('tx-001');

      expect(success, isTrue);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.listState, isA<TransactionListEmpty>());
      verify(() => mockDeleteTransaction('tx-001')).called(1);
      verify(() => mockGetTransactions()).called(1);
    });

    test('11. An toàn khi Dispose: Không bắn exception hay notifyListeners',
        () async {
      notifier.dispose();

      // Các thao tác sau dispose không gây crash
      notifier.clearActionError();
      notifier.clearFieldErrors();
      notifier.clearBoundaryError();
    });

    test('12. update() thành công tự động reload danh sách và trả về true',
        () async {
      when(() => mockUpdateTransaction(any()))
          .thenAnswer((_) async => Success(sampleTx));
      when(() => mockGetTransactions())
          .thenAnswer((_) async => Success([sampleTx]));
      when(() => mockGetSummary())
          .thenAnswer((_) async => const Success(emptySummary));

      final success = await notifier.update(sampleTx);

      expect(success, isTrue);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.listState, isA<TransactionListLoaded>());
      verify(() => mockUpdateTransaction(sampleTx)).called(1);
      verify(() => mockGetTransactions()).called(1);
    });

    test(
        '13. update() thất bại do ValidationException -> đổ lỗi vào fieldErrors',
        () async {
      const valEx =
          ValidationException(field: 'amount', message: 'Số tiền phải dương');
      when(() => mockUpdateTransaction(any()))
          .thenAnswer((_) async => const Failure(valEx));
      when(() => mockErrorHandler.handle(any(), any(),
              source: any(named: 'source')))
          .thenAnswer((_) async => const UserFacingError(
                message: 'Số tiền phải dương',
                canRetry: false,
                severity: Severity.warning,
              ));

      final success = await notifier.update(sampleTx);

      expect(success, isFalse);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.fieldErrors['amount'], equals('Số tiền phải dương'));
      expect(notifier.actionError, isNull);
    });

    test('14. update() thất bại do ServerException -> đổ lỗi vào actionError',
        () async {
      final serverEx = ServerException(statusCode: 500, message: 'Server 500 error');
      when(() => mockUpdateTransaction(any()))
          .thenAnswer((_) async => Failure(serverEx));
      when(() => mockErrorHandler.handle(any(), any(),
              source: any(named: 'source')))
          .thenAnswer((_) async => const UserFacingError(
                message: 'Lỗi máy chủ',
                canRetry: true,
                severity: Severity.error,
              ));

      final success = await notifier.update(sampleTx);

      expect(success, isFalse);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.actionError?.message, equals('Lỗi máy chủ'));
      expect(notifier.fieldErrors, isEmpty);
    });

    test(
        '15. delete() thất bại do ServerException -> gán vào actionError và trả về false',
        () async {
      final serverEx = ServerException(statusCode: 500, message: 'Delete failed on server');
      when(() => mockDeleteTransaction('tx-001'))
          .thenAnswer((_) async => Failure(serverEx));
      when(() => mockErrorHandler.handle(any(), any(),
              source: any(named: 'source')))
          .thenAnswer((_) async => const UserFacingError(
                message: 'Không thể xóa giao dịch',
                canRetry: true,
                severity: Severity.error,
              ));

      final success = await notifier.delete('tx-001');

      expect(success, isFalse);
      expect(notifier.isSubmitting, isFalse);
      expect(notifier.actionError?.message, equals('Không thể xóa giao dịch'));
    });

    test(
        '16. load() khi getTransactions thành công nhưng getSummary thất bại -> TransactionListError',
        () async {
      when(() => mockGetTransactions())
          .thenAnswer((_) async => Success([sampleTx]));
      final serverEx = ServerException(statusCode: 500, message: 'Summary service unavailable');
      when(() => mockGetSummary())
          .thenAnswer((_) async => Failure(serverEx));
      when(() => mockErrorHandler.handle(any(), any(),
              source: any(named: 'source')))
          .thenAnswer((_) async => const UserFacingError(
                message: 'Không thể tính toán số dư',
                canRetry: true,
                severity: Severity.error,
              ));

      await notifier.load();

      expect(notifier.listState, isA<TransactionListError>());
      final errState = notifier.listState as TransactionListError;
      expect(errState.error.message, equals('Không thể tính toán số dư'));
    });

    test('17. clearActionError() xóa bỏ actionError hiện có', () async {
      final serverEx = ServerException(statusCode: 500, message: 'Action failure');
      when(() => mockDeleteTransaction('tx-001'))
          .thenAnswer((_) async => Failure(serverEx));
      when(() => mockErrorHandler.handle(any(), any(),
              source: any(named: 'source')))
          .thenAnswer((_) async => const UserFacingError(
                message: 'Lỗi hành động',
                canRetry: true,
                severity: Severity.error,
              ));

      await notifier.delete('tx-001');
      expect(notifier.actionError, isNotNull);

      notifier.clearActionError();
      expect(notifier.actionError, isNull);
    });
  });
}
