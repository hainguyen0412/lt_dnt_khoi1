import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/utils/loggable_mixin.dart';
import '../../core/utils/non_fatal_reporter.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/data_source.dart';
import '../models/transaction_model.dart';

/// Lớp triển khai cụ thể của [TransactionRepository] tại tầng Data.
///
/// **Chiến lược dữ liệu (Offline Caching Strategy):**
/// 1. **ĐỌC (`getAll`, `getById`):** Luôn thử lấy từ `remoteDataSource` trước.
///    - Thành công -> ghi đè/cập nhật vào `localDataSource` (nếu ghi cache lỗi thì chỉ báo qua
///      `_nonFatalReporter`, vẫn trả về `Success`).
///    - Lỗi -> chuẩn hóa bằng `AppException.from(e, st)`. Chỉ rơi về cache khi lỗi thuộc nhóm
///      sự cố kết nối/máy chủ (`NetworkException`, `RequestTimeoutException`, `ServerException` >= 500, `ParseException`).
///      Các lỗi khác (`NotFoundException`, `ServerException` 4xx, `ValidationException`) trả `Failure` ngay, KHÔNG đọc cache.
///    - Rơi về cache: Cache có dữ liệu -> trả `Success` dữ liệu cache và báo lỗi remote bị nuốt qua `_nonFatalReporter`.
///      Cache cũng lỗi -> trả `Failure` lỗi remote ban đầu và báo lỗi cache qua `_nonFatalReporter`.
/// 2. **GHI (`add`, `update`, `delete`):** Luôn gọi remote trước.
///    - Thành công -> đồng bộ vào local cache (lỗi cache thì báo qua reporter, vẫn trả `Success`).
///    - Lỗi remote -> trả về `Failure`, **tuyệt đối KHÔNG ghi vào local cache**.
/// 3. **Quy tắc NonFatalErrorReporter:** CHỈ báo cáo những lỗi KHÔNG được trả ra trong `Failure`
///    (lỗi bị nuốt). Các lỗi đã gói vào `Failure` sẽ để tầng trên đưa vào pipeline, tránh ghi log trùng lặp.
/// 4. **Cơ chế try-catch-finally (R8):** Mỗi phương thức public đều bọc trong khối đo thời gian
///    bằng `Stopwatch` và `finally`. Khối `finally` được đảm bảo luôn luôn thực thi dù thành công
///    hay phát sinh ngoại lệ, phục vụ việc dừng bộ đếm thời gian và ghi log benchmark.
class TransactionRepositoryImpl
    with LoggableMixin
    implements TransactionRepository {
  final DataSource<TransactionModel> _remoteDataSource;
  final CacheDataSource<TransactionModel> _localDataSource;
  final NonFatalErrorReporter _nonFatalReporter;

  /// Khởi tạo [TransactionRepositoryImpl] qua Constructor Injection.
  TransactionRepositoryImpl({
    required DataSource<TransactionModel> remoteDataSource,
    required CacheDataSource<TransactionModel> localDataSource,
    required NonFatalErrorReporter nonFatalReporter,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _nonFatalReporter = nonFatalReporter;

  /// Thẩm định xem ngoại lệ có thuộc diện được phép rơi về dữ liệu Cache hay không.
  ///
  /// **Nguyên tắc phân loại:**
  /// - `NetworkException`, `RequestTimeoutException`, `ServerException` (mã >= 500), `ParseException`:
  ///   Đại diện cho sự cố hạ tầng / đường truyền mạng / máy chủ tạm thời -> Hợp lý để dùng cache offline.
  /// - `NotFoundException`, `ServerException` (mã 4xx), `ValidationException`:
  ///   Đại diện cho việc tài nguyên không tồn tại hoặc yêu cầu phía client bị sai -> KHÔNG được rơi về cache.
  bool _shouldFallbackToCache(AppException error) {
    return switch (error) {
      NetworkException() => true,
      RequestTimeoutException() => true,
      ServerException(:final statusCode) => statusCode >= 500,
      ParseException() => true,
      _ => false,
    };
  }

  @override
  Future<Result<List<Transaction>>> getAll() async {
    final stopwatch = Stopwatch()..start();
    try {
      try {
        logDebug('Fetching all transactions from remote data source...');
        final remoteModels = await _remoteDataSource.getAll();

        // Cố gắng đồng bộ đè danh sách mới vào cache
        try {
          await _localDataSource.replaceAll(remoteModels);
        } catch (cacheError, cacheSt) {
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
        }

        return Success(remoteModels.map((m) => m.toEntity()).toList());
      } catch (remoteError, remoteSt) {
        final appEx = AppException.from(remoteError, remoteSt);

        if (!_shouldFallbackToCache(appEx)) {
          return Failure(appEx);
        }

        logWarning(
            'Remote failed with ${appEx.runtimeType}. Falling back to local cache...');
        try {
          final cachedModels = await _localDataSource.getAll();
          // Báo lỗi remote bị nuốt qua reporter
          _nonFatalReporter(remoteError, remoteSt,
              source: 'TransactionRepositoryImpl');
          return Success(cachedModels.map((m) => m.toEntity()).toList());
        } catch (cacheError, cacheSt) {
          // Báo lỗi cache qua reporter, trả về Failure với lỗi remote ban đầu
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
          return Failure(appEx);
        }
      }
    } catch (unexpectedError, unexpectedSt) {
      return Failure(AppException.from(unexpectedError, unexpectedSt));
    } finally {
      stopwatch.stop();
      logDebug('getAll() completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  @override
  Future<Result<Transaction>> getById(String id) async {
    final stopwatch = Stopwatch()..start();
    try {
      try {
        logDebug('Fetching transaction $id from remote data source...');
        final remoteModel = await _remoteDataSource.getById(id);

        // Cố gắng cập nhật vào cache
        try {
          try {
            await _localDataSource.update(remoteModel);
          } catch (_) {
            await _localDataSource.add(remoteModel);
          }
        } catch (cacheError, cacheSt) {
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
        }

        return Success(remoteModel.toEntity());
      } catch (remoteError, remoteSt) {
        final appEx = AppException.from(remoteError, remoteSt);

        if (!_shouldFallbackToCache(appEx)) {
          return Failure(appEx);
        }

        logWarning(
            'Remote getById failed. Falling back to local cache for id $id...');
        try {
          final cachedModel = await _localDataSource.getById(id);
          _nonFatalReporter(remoteError, remoteSt,
              source: 'TransactionRepositoryImpl');
          return Success(cachedModel.toEntity());
        } catch (cacheError, cacheSt) {
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
          return Failure(appEx);
        }
      }
    } catch (unexpectedError, unexpectedSt) {
      return Failure(AppException.from(unexpectedError, unexpectedSt));
    } finally {
      stopwatch.stop();
      logDebug('getById($id) completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  @override
  Future<Result<Transaction>> add(Transaction transaction) async {
    final stopwatch = Stopwatch()..start();
    try {
      final model = TransactionModel.fromEntity(transaction);
      try {
        logDebug('Adding transaction ${model.id} to remote...');
        final addedModel = await _remoteDataSource.add(model);

        // Đồng bộ vào cache
        try {
          await _localDataSource.add(addedModel);
        } catch (cacheError, cacheSt) {
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
        }

        return Success(addedModel.toEntity());
      } catch (remoteError, remoteSt) {
        // Ghi remote lỗi -> trả Failure ngay, không ghi cache giả
        return Failure(AppException.from(remoteError, remoteSt));
      }
    } catch (unexpectedError, unexpectedSt) {
      return Failure(AppException.from(unexpectedError, unexpectedSt));
    } finally {
      stopwatch.stop();
      logDebug(
          'add(${transaction.id}) completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  @override
  Future<Result<Transaction>> update(Transaction transaction) async {
    final stopwatch = Stopwatch()..start();
    try {
      final model = TransactionModel.fromEntity(transaction);
      try {
        logDebug('Updating transaction ${model.id} on remote...');
        final updatedModel = await _remoteDataSource.update(model);

        // Đồng bộ vào cache
        try {
          await _localDataSource.update(updatedModel);
        } catch (cacheError, cacheSt) {
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
        }

        return Success(updatedModel.toEntity());
      } catch (remoteError, remoteSt) {
        return Failure(AppException.from(remoteError, remoteSt));
      }
    } catch (unexpectedError, unexpectedSt) {
      return Failure(AppException.from(unexpectedError, unexpectedSt));
    } finally {
      stopwatch.stop();
      logDebug(
          'update(${transaction.id}) completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    final stopwatch = Stopwatch()..start();
    try {
      try {
        logDebug('Deleting transaction $id on remote...');
        await _remoteDataSource.delete(id);

        // Đồng bộ vào cache
        try {
          await _localDataSource.delete(id);
        } catch (cacheError, cacheSt) {
          _nonFatalReporter(cacheError, cacheSt,
              source: 'TransactionRepositoryImpl');
        }

        return const Success(null);
      } catch (remoteError, remoteSt) {
        return Failure(AppException.from(remoteError, remoteSt));
      }
    } catch (unexpectedError, unexpectedSt) {
      return Failure(AppException.from(unexpectedError, unexpectedSt));
    } finally {
      stopwatch.stop();
      logDebug('delete($id) completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  @override
  Future<Result<TransactionSummary>> getSummary() async {
    final stopwatch = Stopwatch()..start();
    try {
      final allResult = await getAll();
      final summaryResult = switch (allResult) {
        Success(:final data) => Success(calculateSummary(data)),
        Failure(:final error) => Failure<TransactionSummary>(error),
      };
      return summaryResult;
    } catch (unexpectedError, unexpectedSt) {
      return Failure(AppException.from(unexpectedError, unexpectedSt));
    } finally {
      stopwatch.stop();
      logDebug('getSummary() completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  /// Hàm thuần (Pure function) tính toán tổng thu, tổng chi và số dư từ danh sách giao dịch.
  static TransactionSummary calculateSummary(List<Transaction> transactions) {
    int totalIncome = 0;
    int totalExpense = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount.amount;
      } else {
        totalExpense += t.amount.amount;
      }
    }

    return TransactionSummary(
      totalIncome: Money(totalIncome),
      totalExpense: Money(totalExpense),
    );
  }
}
