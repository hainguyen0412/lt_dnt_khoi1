import 'dart:io';

import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/errors/cache_storage_error.dart';
import 'package:expense_tracker/core/errors/http_status_error.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:expense_tracker/data/datasources/data_source.dart';
import 'package:expense_tracker/data/models/transaction_model.dart';
import 'package:expense_tracker/data/repositories/transaction_repository_impl.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemoteDataSource extends Mock
    implements DataSource<TransactionModel> {}

class MockLocalDataSource extends Mock
    implements CacheDataSource<TransactionModel> {}

abstract class NonFatalReporterCaller {
  void call(Object error, StackTrace stackTrace, {String? source});
}

class MockNonFatalReporter extends Mock implements NonFatalReporterCaller {}

class FakeTransactionModel extends Fake implements TransactionModel {}

void main() {
  late MockRemoteDataSource mockRemote;
  late MockLocalDataSource mockLocal;
  late MockNonFatalReporter mockReporter;
  late TransactionRepositoryImpl repository;

  final now = DateTime(2026, 10, 14, 10, 0);

  final sampleModel = TransactionModel(
    id: 'tx-1',
    type: 'income',
    title: 'Tiền thưởng',
    amount: 5000000,
    category: 'salary',
    date: now,
    createdAt: now,
  );

  final sampleEntity = Transaction.income(
    id: 'tx-1',
    title: 'Tiền thưởng',
    amount: const Money(5000000),
    category: Category.salary,
    date: now,
    createdAt: now,
  );

  setUpAll(() {
    registerFallbackValue(FakeTransactionModel());
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockRemote = MockRemoteDataSource();
    mockLocal = MockLocalDataSource();
    mockReporter = MockNonFatalReporter();

    repository = TransactionRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
      nonFatalReporter: mockReporter.call,
    );
  });

  group('T-201: TransactionRepositoryImpl Tests', () {
    test('a) remote OK -> trả Success và cache được cập nhật (replaceAll)',
        () async {
      when(() => mockRemote.getAll()).thenAnswer((_) async => [sampleModel]);
      when(() => mockLocal.replaceAll(any())).thenAnswer((_) async {});

      final result = await repository.getAll();

      expect(result.isSuccess, isTrue);
      final list = (result as Success<List<Transaction>>).data;
      expect(list.length, equals(1));
      expect(list.first.id, equals('tx-1'));

      verify(() => mockLocal.replaceAll([sampleModel])).called(1);
      verifyNever(
          () => mockReporter.call(any(), any(), source: any(named: 'source')));
    });

    test(
        'b) remote ném SocketException -> Success dữ liệu cache, reporter được gọi đúng 1 lần',
        () async {
      when(() => mockRemote.getAll()).thenThrow(
        const SocketException('Failed host lookup'),
      );
      when(() => mockLocal.getAll()).thenAnswer((_) async => [sampleModel]);

      final result = await repository.getAll();

      expect(result.isSuccess, isTrue);
      final list = (result as Success<List<Transaction>>).data;
      expect(list.length, equals(1));
      expect(list.first.title, equals('Tiền thưởng'));

      // Reporter được gọi đúng 1 lần để báo lỗi remote bị nuốt
      verify(() => mockReporter.call(
            any(that: isA<SocketException>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'c) remote 500 + cache lỗi -> Failure(ServerException), reporter được gọi 1 lần với lỗi cache',
        () async {
      when(() => mockRemote.getAll()).thenThrow(
        const HttpStatusError(500, 'Database crashed'),
      );
      when(() => mockLocal.getAll()).thenThrow(
        const CacheStorageError('Disk full'),
      );

      final result = await repository.getAll();

      expect(result.isFailure, isTrue);
      final failure = result as Failure<List<Transaction>>;
      expect(failure.error, isA<ServerException>());
      expect((failure.error as ServerException).statusCode, equals(500));

      // Lỗi remote được trả trong Failure nên KHÔNG report.
      // Chỉ report lỗi cache bị nuốt!
      verify(() => mockReporter.call(
            any(that: isA<CacheStorageError>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'd) getById remote 404 -> Failure(NotFoundException), verifyNever đọc cache',
        () async {
      when(() => mockRemote.getById('tx-999')).thenThrow(
        const HttpStatusError(404, 'Not found'),
      );

      final result = await repository.getById('tx-999');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect(failure.error, isA<NotFoundException>());

      // Tuyệt đối không đọc cache với lỗi 404
      verifyNever(() => mockLocal.getById(any()));
      // Lỗi 404 đã trả trong Failure nên không report
      verifyNever(
          () => mockReporter.call(any(), any(), source: any(named: 'source')));
    });

    test('e) remote trả JSON hỏng (ParseException) -> rơi về cache thành công',
        () async {
      const parseError = ParseException(message: 'Invalid field [amount]');
      when(() => mockRemote.getAll()).thenThrow(parseError);
      when(() => mockLocal.getAll()).thenAnswer((_) async => [sampleModel]);

      final result = await repository.getAll();

      expect(result.isSuccess, isTrue);
      expect(
          (result as Success<List<Transaction>>).data.first.id, equals('tx-1'));

      verify(() => mockReporter.call(
            parseError,
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test('f) add khi remote lỗi -> Failure, verifyNever ghi cache', () async {
      when(() => mockRemote.add(any())).thenThrow(
        const SocketException('No internet'),
      );

      final result = await repository.add(sampleEntity);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect(failure.error, isA<NetworkException>());

      // Tuyệt đối không ghi cache khi remote thất bại
      verifyNever(() => mockLocal.add(any()));
      verifyNever(
          () => mockReporter.call(any(), any(), source: any(named: 'source')));
    });

    test(
        'g) add OK nhưng ghi cache lỗi -> Success, reporter được gọi với lỗi cache',
        () async {
      when(() => mockRemote.add(any())).thenAnswer((_) async => sampleModel);
      when(() => mockLocal.add(any())).thenThrow(
        const CacheStorageError('SharedPreferences error'),
      );

      final result = await repository.add(sampleEntity);

      expect(result.isSuccess, isTrue);
      expect((result as Success<Transaction>).data.id, equals('tx-1'));

      verify(() => mockReporter.call(
            any(that: isA<CacheStorageError>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'h) remote ném lỗi lạ (StateError) -> trả Failure(UnknownException), không crash ra ngoài',
        () async {
      when(() => mockRemote.getAll())
          .thenThrow(StateError('Invalid internal state'));

      final result = await repository.getAll();

      expect(result.isFailure, isTrue);
      final failure = result as Failure<List<Transaction>>;
      expect(failure.error, isA<UnknownException>());
      expect(failure.error.code, equals('UNKNOWN_ERROR'));
    });

    test('i) update và delete: thành công đồng bộ cache và lỗi báo Failure',
        () async {
      // update thành công
      when(() => mockRemote.update(any())).thenAnswer((_) async => sampleModel);
      when(() => mockLocal.update(any())).thenAnswer((_) async => sampleModel);

      final updateResult = await repository.update(sampleEntity);
      expect(updateResult.isSuccess, isTrue);
      verify(() => mockLocal.update(any())).called(1);

      // delete thành công
      when(() => mockRemote.delete('tx-1')).thenAnswer((_) async {});
      when(() => mockLocal.delete('tx-1')).thenAnswer((_) async {});

      final deleteResult = await repository.delete('tx-1');
      expect(deleteResult.isSuccess, isTrue);
      verify(() => mockLocal.delete('tx-1')).called(1);
    });

    test('j) getSummary tính toán chính xác tổng thu, chi và số dư', () async {
      final txIncome = Transaction.income(
        id: 't-inc',
        title: 'Lương',
        amount: const Money(10000000),
        category: Category.salary,
        date: now,
        createdAt: now,
      );
      final txExpense = Transaction.expense(
        id: 't-exp',
        title: 'Tiền trọ',
        amount: const Money(3000000),
        category: Category.bills,
        date: now,
        createdAt: now,
      );

      when(() => mockRemote.getAll()).thenAnswer(
        (_) async => [
          TransactionModel.fromEntity(txIncome),
          TransactionModel.fromEntity(txExpense),
        ],
      );
      when(() => mockLocal.replaceAll(any())).thenAnswer((_) async {});

      final result = await repository.getSummary();

      expect(result.isSuccess, isTrue);
      final summary = (result as Success<TransactionSummary>).data;
      expect(summary.totalIncome.amount, equals(10000000));
      expect(summary.totalExpense.amount, equals(3000000));
      expect(summary.balance.amount, equals(7000000));
    });

    test(
        'k) getById: remote ném SocketException -> Fallback đọc từ cache thành công, reporter báo lỗi remote',
        () async {
      when(() => mockRemote.getById('tx-1')).thenThrow(
        const SocketException('Failed host lookup'),
      );
      when(() => mockLocal.getById('tx-1'))
          .thenAnswer((_) async => sampleModel);

      final result = await repository.getById('tx-1');

      expect(result.isSuccess, isTrue);
      final tx = (result as Success<Transaction>).data;
      expect(tx.id, equals('tx-1'));
      verify(() => mockReporter.call(
            any(that: isA<SocketException>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'l) getById: remote ném SocketException và cache cũng ném lỗi -> Trả về Failure remote gốc',
        () async {
      when(() => mockRemote.getById('tx-1')).thenThrow(
        const SocketException('Failed host lookup'),
      );
      when(() => mockLocal.getById('tx-1')).thenThrow(
        const CacheStorageError('Corrupt cache entry'),
      );

      final result = await repository.getById('tx-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<Transaction>;
      expect(failure.error, isA<NetworkException>());
      expect(failure.error.code, equals('NETWORK_ERROR'));
      verify(() => mockReporter.call(
            any(that: isA<CacheStorageError>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'm) getAll: remote OK nhưng local.replaceAll ném CacheStorageError -> Vẫn trả về Success và gọi reporter',
        () async {
      when(() => mockRemote.getAll()).thenAnswer((_) async => [sampleModel]);
      when(() => mockLocal.replaceAll(any())).thenThrow(
        const CacheStorageError('Write disk failed'),
      );

      final result = await repository.getAll();

      expect(result.isSuccess, isTrue);
      final list = (result as Success<List<Transaction>>).data;
      expect(list.length, equals(1));
      verify(() => mockReporter.call(
            any(that: isA<CacheStorageError>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'n) update: remote OK nhưng local.update ném CacheStorageError -> Vẫn trả về Success và gọi reporter',
        () async {
      when(() => mockRemote.update(any())).thenAnswer((_) async => sampleModel);
      when(() => mockLocal.update(any())).thenThrow(
        const CacheStorageError('Cache update failed'),
      );

      final result = await repository.update(sampleEntity);

      expect(result.isSuccess, isTrue);
      verify(() => mockReporter.call(
            any(that: isA<CacheStorageError>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'o) delete: remote OK nhưng local.delete ném CacheStorageError -> Vẫn trả về Success và gọi reporter',
        () async {
      when(() => mockRemote.delete('tx-1')).thenAnswer((_) async {});
      when(() => mockLocal.delete('tx-1')).thenThrow(
        const CacheStorageError('Cache delete failed'),
      );

      final result = await repository.delete('tx-1');

      expect(result.isSuccess, isTrue);
      verify(() => mockReporter.call(
            any(that: isA<CacheStorageError>()),
            any(),
            source: 'TransactionRepositoryImpl',
          )).called(1);
    });

    test(
        'p) getSummary: remote ném StateError bất ngờ -> Trả về Failure(UnknownException)',
        () async {
      when(() => mockRemote.getAll()).thenThrow(
        StateError('Crash in summary calculation'),
      );

      final result = await repository.getSummary();

      expect(result.isFailure, isTrue);
      final failure = result as Failure<TransactionSummary>;
      expect(failure.error, isA<UnknownException>());
      expect(failure.error.code, equals('UNKNOWN_ERROR'));
    });
  });
}
