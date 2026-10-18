import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/domain/entities/transaction_summary.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:expense_tracker/domain/repositories/transaction_repository.dart';
import 'package:expense_tracker/domain/usecases/add_transaction.dart';
import 'package:expense_tracker/domain/usecases/delete_transaction.dart';
import 'package:expense_tracker/domain/usecases/get_summary.dart';
import 'package:expense_tracker/domain/usecases/get_transaction_by_id.dart';
import 'package:expense_tracker/domain/usecases/get_transactions.dart';
import 'package:expense_tracker/domain/usecases/update_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockTransactionRepository mockRepository;
  final fixedClock = DateTime(2026, 10, 14, 12, 0, 0);
  const fixedId = 'test-generated-id-123';

  setUpAll(() {
    registerFallbackValue(FakeTransaction());
  });

  setUp(() {
    mockRepository = MockTransactionRepository();
  });

  group('T-105: AddTransaction UseCase Tests', () {
    late AddTransaction addTransaction;

    setUp(() {
      addTransaction = AddTransaction(
        mockRepository,
        idGenerator: () => fixedId,
        clock: () => fixedClock,
      );
    });

    test(
        '1. Thêm với số tiền âm -> Trả về Failure(field: amount), KHÔNG gọi repository',
        () async {
      final invalidDraft = TransactionDraft(
        type: TransactionType.expense,
        title: 'Mua cafe',
        amount: const Money(-30000),
        category: Category.food,
        date: fixedClock,
      );

      final result = await addTransaction(invalidDraft);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect(failure.error, isA<ValidationException>());
      expect((failure.error as ValidationException).field, equals('amount'));

      verifyNever(() => mockRepository.add(any()));
    });

    test(
        '2. Thêm với tiêu đề rỗng -> Trả về Failure(field: title), KHÔNG gọi repository',
        () async {
      final invalidDraft = TransactionDraft(
        type: TransactionType.expense,
        title: '   ',
        amount: const Money(30000),
        category: Category.food,
        date: fixedClock,
      );

      final result = await addTransaction(invalidDraft);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect((failure.error as ValidationException).field, equals('title'));

      verifyNever(() => mockRepository.add(any()));
    });

    test(
        '3. Thêm với ngày tương lai xa -> Trả về Failure(field: date), KHÔNG gọi repository',
        () async {
      final invalidDraft = TransactionDraft(
        type: TransactionType.expense,
        title: 'Mua cafe',
        amount: const Money(30000),
        category: Category.food,
        date: fixedClock.add(const Duration(days: 10)),
      );

      final result = await addTransaction(invalidDraft);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect((failure.error as ValidationException).field, equals('date'));

      verifyNever(() => mockRepository.add(any()));
    });

    test(
        '4. Thêm bản nháp hợp lệ -> Gọi repository.add đúng 1 lần với id và clock được tiêm',
        () async {
      final validDraft = TransactionDraft(
        type: TransactionType.income,
        title: 'Thưởng đồ án',
        amount: const Money(1000000),
        category: Category.salary,
        date: fixedClock,
      );

      final expectedTx = Transaction(
        id: fixedId,
        type: TransactionType.income,
        title: 'Thưởng đồ án',
        amount: const Money(1000000),
        category: Category.salary,
        date: fixedClock,
        createdAt: fixedClock,
      );

      when(() => mockRepository.add(any()))
          .thenAnswer((_) async => Success(expectedTx));

      final result = await addTransaction(validDraft);

      expect(result.isSuccess, isTrue);
      expect((result as Success<Transaction>).data, equals(expectedTx));

      verify(() => mockRepository.add(
            any(
              that: isA<Transaction>()
                  .having((t) => t.id, 'id', fixedId)
                  .having((t) => t.createdAt, 'createdAt', fixedClock)
                  .having((t) => t.title, 'title', 'Thưởng đồ án'),
            ),
          )).called(1);
    });

    test(
        '5. Khởi tạo mặc định không truyền idGenerator và clock -> Sinh ID hợp lệ và gắn createdAt hiện tại',
        () async {
      final defaultAddTransaction = AddTransaction(mockRepository);
      final validDraft = TransactionDraft(
        type: TransactionType.income,
        title: 'Lương tháng',
        amount: const Money(15000000),
        category: Category.salary,
        date: DateTime.now(),
      );

      when(() => mockRepository.add(any())).thenAnswer((invocation) async {
        final tx = invocation.positionalArguments.first as Transaction;
        return Success(tx);
      });

      final result = await defaultAddTransaction(validDraft);

      expect(result.isSuccess, isTrue);
      final created = (result as Success<Transaction>).data;
      expect(created.id, isNotEmpty);
      expect(created.createdAt, isNotNull);
      verify(() => mockRepository.add(any())).called(1);
    });

    test('6. Repository ném Failure -> Usecase truyền nguyên vẹn Failure lên',
        () async {
      final validDraft = TransactionDraft(
        type: TransactionType.expense,
        title: 'Tiền trọ',
        amount: const Money(2500000),
        category: Category.bills,
        date: fixedClock,
      );

      const networkError = NetworkException(message: 'No internet connection');
      when(() => mockRepository.add(any()))
          .thenAnswer((_) async => const Failure(networkError));

      final result = await addTransaction(validDraft);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect(identical(failure.error, networkError), isTrue);
    });
  });

  group('T-105: UpdateTransaction UseCase Tests', () {
    late UpdateTransaction updateTransaction;

    setUp(() {
      updateTransaction = UpdateTransaction(
        mockRepository,
        clock: () => fixedClock,
      );
    });

    test(
        '6. Cập nhật transaction không hợp lệ -> Trả về Failure, KHÔNG gọi repository',
        () async {
      final invalidTx = Transaction.expense(
        id: 'tx-update-1',
        title: '',
        amount: const Money(50000),
        category: Category.food,
        date: fixedClock,
        createdAt: fixedClock,
      );

      final result = await updateTransaction(invalidTx);

      expect(result.isFailure, isTrue);
      expect(
          (result as Failure<Transaction>).error, isA<ValidationException>());
      verifyNever(() => mockRepository.update(any()));
    });

    test(
        '7. Cập nhật hợp lệ -> Tạo bản sao có updatedAt từ clock() và gọi repository.update',
        () async {
      final originalTx = Transaction.expense(
        id: 'tx-update-2',
        title: 'Ăn trưa',
        amount: const Money(40000),
        category: Category.food,
        date: fixedClock,
        createdAt: fixedClock.subtract(const Duration(hours: 2)),
      );

      when(() => mockRepository.update(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments.first as Transaction),
      );

      final result = await updateTransaction(originalTx);

      expect(result.isSuccess, isTrue);
      final updatedResult = (result as Success<Transaction>).data;
      expect(updatedResult.updatedAt, equals(fixedClock));

      verify(() => mockRepository.update(
            any(
              that: isA<Transaction>()
                  .having((t) => t.id, 'id', 'tx-update-2')
                  .having((t) => t.updatedAt, 'updatedAt', fixedClock),
            ),
          )).called(1);
    });

    test('8. Repository trả về Failure khi update -> Truyền nguyên Failure lên',
        () async {
      final validTx = Transaction.expense(
        id: 'tx-not-found',
        title: 'Mua thuốc lá',
        amount: const Money(20000),
        category: Category.other,
        date: fixedClock,
        createdAt: fixedClock,
      );

      const notFound = NotFoundException(message: 'Item not found');
      when(() => mockRepository.update(any()))
          .thenAnswer((_) async => const Failure(notFound));

      final result = await updateTransaction(validTx);

      expect(result.isFailure, isTrue);
      expect(
          identical((result as Failure<Transaction>).error, notFound), isTrue);
    });
  });

  group('T-105: DeleteTransaction UseCase Tests', () {
    late DeleteTransaction deleteTransaction;

    setUp(() {
      deleteTransaction = DeleteTransaction(mockRepository);
    });

    test(
        '9. id rỗng hoặc khoảng trắng -> Trả về Failure(field: id), KHÔNG gọi repository',
        () async {
      final resultEmpty = await deleteTransaction('');
      final resultWhitespace = await deleteTransaction('   ');

      expect(resultEmpty.isFailure, isTrue);
      expect((resultEmpty as Failure<void>).error, isA<ValidationException>());
      expect(((resultEmpty).error as ValidationException).field, equals('id'));

      expect(resultWhitespace.isFailure, isTrue);
      verifyNever(() => mockRepository.delete(any()));
    });

    test('10. id hợp lệ -> Gọi repository.delete với id đã trim', () async {
      when(() => mockRepository.delete('tx-123'))
          .thenAnswer((_) async => const Success(null));

      final result = await deleteTransaction('  tx-123  ');

      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.delete('tx-123')).called(1);
    });

    test(
        '11. Repository trả về Failure khi delete -> Truyền nguyên Failure lên',
        () async {
      final serverErr = ServerException(statusCode: 500, message: 'DB Error');
      when(() => mockRepository.delete('tx-err'))
          .thenAnswer((_) async => Failure(serverErr));

      final result = await deleteTransaction('tx-err');

      expect(result.isFailure, isTrue);
      expect(identical((result as Failure<void>).error, serverErr), isTrue);
    });
  });

  group('T-105: GetTransactions, GetTransactionById & GetSummary Tests', () {
    test('12. GetTransactions: Thành công và thất bại', () async {
      final getTransactions = GetTransactions(mockRepository);
      final list = <Transaction>[];

      when(() => mockRepository.getAll())
          .thenAnswer((_) async => Success(list));
      final successResult = await getTransactions();
      expect(successResult.isSuccess, isTrue);

      const netErr = NetworkException(message: 'Timeout');
      when(() => mockRepository.getAll())
          .thenAnswer((_) async => const Failure(netErr));
      final failureResult = await getTransactions();
      expect(failureResult.isFailure, isTrue);
      expect(
          identical(
              (failureResult as Failure<List<Transaction>>).error, netErr),
          isTrue);
    });

    test(
        '13. GetTransactionById: id rỗng -> Failure; id hợp lệ -> gọi repository',
        () async {
      final getById = GetTransactionById(mockRepository);

      final emptyResult = await getById('  ');
      expect(emptyResult.isFailure, isTrue);
      expect((emptyResult as Failure<Transaction>).error,
          isA<ValidationException>());
      verifyNever(() => mockRepository.getById(any()));

      final dummyTx = Transaction.income(
        id: 'tx-found',
        title: 'Lương',
        amount: const Money(10000000),
        category: Category.salary,
        date: fixedClock,
        createdAt: fixedClock,
      );

      when(() => mockRepository.getById('tx-found'))
          .thenAnswer((_) async => Success(dummyTx));
      final successResult = await getById('tx-found');
      expect(successResult.isSuccess, isTrue);
      expect(
          (successResult as Success<Transaction>).data.id, equals('tx-found'));
    });

    test('14. GetSummary: Thành công và chuyển tiếp lỗi', () async {
      final getSummary = GetSummary(mockRepository);
      const summary = TransactionSummary(
        totalIncome: Money(5000000),
        totalExpense: Money(2000000),
      );

      when(() => mockRepository.getSummary())
          .thenAnswer((_) async => const Success(summary));
      final successResult = await getSummary();
      expect(successResult.isSuccess, isTrue);
      expect((successResult as Success<TransactionSummary>).data.balance.amount,
          equals(3000000));

      const cacheErr = CacheException(message: 'Corrupted cache');
      when(() => mockRepository.getSummary())
          .thenAnswer((_) async => const Failure(cacheErr));
      final failureResult = await getSummary();
      expect(failureResult.isFailure, isTrue);
      expect(
          identical(
              (failureResult as Failure<TransactionSummary>).error, cacheErr),
          isTrue);
    });
  });
}
