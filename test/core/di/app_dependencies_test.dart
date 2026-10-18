import 'dart:async';
import 'dart:io';

import 'package:expense_tracker/core/di/app_dependencies.dart';
import 'package:expense_tracker/core/error_handling/error_logger.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/errors/http_status_error.dart';
import 'package:expense_tracker/core/simulation/failure_mode.dart';
import 'package:expense_tracker/data/datasources/data_source.dart';
import 'package:expense_tracker/data/models/transaction_model.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DataSource giả lập hoàn toàn trong bộ nhớ RAM phục vụ kiểm thử hoán đổi component (OCP).
class StubRemoteDataSource implements DataSource<TransactionModel> {
  final List<TransactionModel> items = <TransactionModel>[];

  @override
  Future<List<TransactionModel>> getAll() async => List.unmodifiable(items);

  @override
  Future<TransactionModel> getById(String id) async {
    return items.firstWhere((e) => e.id == id);
  }

  @override
  Future<TransactionModel> add(TransactionModel item) async {
    items.add(item);
    return item;
  }

  @override
  Future<TransactionModel> update(TransactionModel item) async {
    final index = items.indexWhere((e) => e.id == item.id);
    if (index != -1) items[index] = item;
    return item;
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((e) => e.id == id);
  }
}

/// CacheDataSource giả lập hoàn toàn trong bộ nhớ RAM.
class StubLocalDataSource extends StubRemoteDataSource
    implements CacheDataSource<TransactionModel> {
  @override
  Future<void> replaceAll(List<TransactionModel> newItems) async {
    items
      ..clear()
      ..addAll(newItems);
  }
}

/// Logger giả lập ghi nhận các LogEntry trong quá trình kiểm thử.
class StubErrorLogger implements ErrorLogger {
  final List<LogEntry> logs = <LogEntry>[];
  void Function(LogEntry)? onLog;

  @override
  Future<void> log(LogEntry entry) async {
    logs.add(entry);
    onLog?.call(entry);
  }

  @override
  Future<List<LogEntry>> readAll() async => List.unmodifiable(logs);

  @override
  Future<void> clear() async => logs.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('T-206: AppDependencies Composition Root Tests', () {
    test(
        '1. Hoán đổi DataSource bằng stub -> Repository và toàn bộ 6 usecases hoạt động chuẩn xác',
        () async {
      final stubRemote = StubRemoteDataSource();
      final stubLocal = StubLocalDataSource();
      final stubLogger = StubErrorLogger();

      // Lắp ráp AppDependencies với các overrides thay thế
      final dependencies = await buildDependencies(
        remoteDataSourceOverride: stubRemote,
        localDataSourceOverride: stubLocal,
        loggersOverride: [stubLogger],
        fileLoggerOverride: stubLogger,
        idGeneratorOverride: () => 'custom_id_123',
        clockOverride: () => DateTime(2026, 10, 15, 8, 0),
      );

      // Kiểm tra tính toàn vẹn của các trường
      expect(dependencies.fileLogger, equals(stubLogger));
      expect(dependencies.loggers, contains(stubLogger));

      // Thêm mới giao dịch thông qua Usecase
      final draft = TransactionDraft(
        type: TransactionType.expense,
        title: 'Cà phê sáng',
        amount: const Money(35000),
        category: Category.food,
        date: DateTime(2026, 10, 15, 7, 30),
      );

      final addResult = await dependencies.addTransaction(draft);
      expect(addResult.isSuccess, isTrue);

      final created = addResult.getOrElse((e) => throw e);
      expect(created.id, equals('custom_id_123'));
      expect(created.title, equals('Cà phê sáng'));

      // Kiểm tra GetAll qua Usecase
      final getAllResult = await dependencies.getTransactions();
      expect(getAllResult.isSuccess, isTrue);
      final list = getAllResult.getOrElse((e) => throw e);
      expect(list.length, equals(1));
      expect(list.first.id, equals('custom_id_123'));

      // Kiểm tra GetSummary qua Usecase
      final summaryResult = await dependencies.getSummary();
      expect(summaryResult.isSuccess, isTrue);
      final summary = summaryResult.getOrElse((e) => throw e);
      expect(summary.totalExpense.amount, equals(35000));
      expect(summary.totalIncome.amount, equals(0));

      // Kiểm tra Delete qua Usecase
      final deleteResult =
          await dependencies.deleteTransaction('custom_id_123');
      expect(deleteResult.isSuccess, isTrue);

      final listAfterDelete =
          (await dependencies.getTransactions()).getOrElse((e) => throw e);
      expect(listAfterDelete, isEmpty);
    });

    test(
        '2. Thay đổi FailureSimulator.mode -> FakeRemoteDataSource ném đúng loại lỗi tương ứng',
        () async {
      final simulator = FailureSimulator();
      final stubLocal = StubLocalDataSource();
      final stubLogger = StubErrorLogger();

      final dependencies = await buildDependencies(
        failureSimulatorOverride: simulator,
        localDataSourceOverride: stubLocal,
        loggersOverride: [stubLogger],
        fileLoggerOverride: stubLogger,
      );

      // a) Chế độ Network -> remote ném SocketException
      simulator.mode = FailureMode.network;
      await expectLater(
        dependencies.remoteDataSource.getAll(),
        throwsA(isA<SocketException>()),
      );

      // b) Chế độ Timeout -> remote ném TimeoutException
      simulator.mode = FailureMode.timeout;
      await expectLater(
        dependencies.remoteDataSource.getAll(),
        throwsA(isA<TimeoutException>()),
      );

      // c) Chế độ Server500 -> remote ném HttpStatusError(500)
      simulator.mode = FailureMode.server500;
      await expectLater(
        dependencies.remoteDataSource.getAll(),
        throwsA(isA<HttpStatusError>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );

      // d) Chế độ BadJson -> remote ném ParseException
      simulator.mode = FailureMode.badJson;
      await expectLater(
        dependencies.remoteDataSource.getAll(),
        throwsA(isA<ParseException>()),
      );
    });

    test(
        '3. NonFatalErrorReporter truyền chính xác lỗi ngầm vào ErrorHandler pipeline',
        () async {
      final stubLogger = StubErrorLogger();
      final completer = Completer<LogEntry>();
      stubLogger.onLog = completer.complete;

      final dependencies = await buildDependencies(
        localDataSourceOverride: StubLocalDataSource(),
        loggersOverride: [stubLogger],
        fileLoggerOverride: stubLogger,
      );

      // Gọi nonFatalReporter
      dependencies.nonFatalReporter(
        const SocketException('Offline sync failure'),
        StackTrace.current,
        source: 'CustomRepoFallback',
      );

      final entry = await completer.future.timeout(const Duration(seconds: 2));
      expect(entry.code, equals('NETWORK_ERROR'));
      expect(entry.source, equals('CustomRepoFallback'));
    });
  });
}
