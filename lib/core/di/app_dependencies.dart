import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/data_source.dart';
import '../../data/datasources/fake_remote_data_source.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/add_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/get_summary.dart';
import '../../domain/usecases/get_transaction_by_id.dart';
import '../../domain/usecases/get_transactions.dart';
import '../../domain/usecases/update_transaction.dart';
import '../error_handling/console_logger.dart';
import '../error_handling/error_handler.dart';
import '../error_handling/error_logger.dart';
import '../error_handling/error_message_mapper.dart';
import '../error_handling/file_logger.dart';
import '../simulation/failure_mode.dart';
import '../utils/non_fatal_reporter.dart';

/// Lớp thuần Dart đóng gói toàn bộ các đối tượng dịch vụ và usecase của ứng dụng.
///
/// **Lý do thiết kế Composition Root (R5, R6):**
/// - **Không dùng Service Locator / DI Framework ngoài:** Không phụ thuộc `get_it` hay code generator,
///   toàn bộ cây phụ thuộc được tạo và nối dây (wiring) bằng Pure Constructor Injection.
/// - **Đóng gói toàn diện:** Chứa đầy đủ các dịch vụ từ tầng Core, Data và Domain, giúp tầng Presentation
///   dễ dàng tiếp cận các dependency thông qua `Provider` mà không vi phạm nguyên tắc Clean Architecture.
/// - **Lưu trữ [fileLogger]:** Giữ riêng tham chiếu tới [fileLogger] để cung cấp cho màn hình
///   Log Viewer (T-306) ở Sprint 3 truy xuất lịch sử lỗi.
class AppDependencies {
  /// Bộ điều khiển trạng thái giả lập lỗi.
  final FailureSimulator failureSimulator;

  /// Nguồn dữ liệu từ xa (Remote DataSource).
  final DataSource<TransactionModel> remoteDataSource;

  /// Bộ nhớ đệm cục bộ (Local Cache DataSource).
  final CacheDataSource<TransactionModel> localDataSource;

  /// Danh sách các bộ ghi log (Console, File...).
  final List<ErrorLogger> loggers;

  /// Bộ ghi log vào tệp tin (phục vụ màn hình Log Viewer).
  final ErrorLogger fileLogger;

  /// Bộ chuyển đổi ngoại lệ sang thông điệp tiếng Việt.
  final ErrorMessageMapper messageMapper;

  /// Bộ xử lý ngoại lệ tập trung (Centralized Error Pipeline).
  final ErrorHandler errorHandler;

  /// Hàm callback báo cáo các lỗi bị nuốt / lỗi thứ cấp ngầm.
  final NonFatalErrorReporter nonFatalReporter;

  /// Repository quản lý giao dịch (Domain Interface).
  final TransactionRepository repository;

  /// Usecase lấy danh sách giao dịch.
  final GetTransactions getTransactions;

  /// Usecase lấy chi tiết giao dịch theo id.
  final GetTransactionById getTransactionById;

  /// Usecase thêm mới giao dịch từ bản nháp.
  final AddTransaction addTransaction;

  /// Usecase cập nhật giao dịch.
  final UpdateTransaction updateTransaction;

  /// Usecase xóa giao dịch.
  final DeleteTransaction deleteTransaction;

  /// Usecase tính toán tổng kết thu chi.
  final GetSummary getSummary;

  /// Khởi tạo [AppDependencies] bất biến với đầy đủ các thành phần đã được lắp ráp.
  const AppDependencies({
    required this.failureSimulator,
    required this.remoteDataSource,
    required this.localDataSource,
    required this.loggers,
    required this.fileLogger,
    required this.messageMapper,
    required this.errorHandler,
    required this.nonFatalReporter,
    required this.repository,
    required this.getTransactions,
    required this.getTransactionById,
    required this.addTransaction,
    required this.updateTransaction,
    required this.deleteTransaction,
    required this.getSummary,
  });
}

/// Hàm lắp ráp toàn bộ cây phụ thuộc của hệ thống (Composition Root Factory Function).
///
/// **Chứng minh nguyên lý Open-Closed (OCP) & Dependency Inversion (DIP):**
/// Hàm này hỗ trợ các tham số tùy chọn `overrides` cho toàn bộ các thành phần.
/// Khi cần thay thế implementation (ví dụ: chuyển từ FakeRemote sang HttpRemote, đổi LocalDataSource
/// sang SQLite, hoặc tiêm Mock trong Unit Test), ta **CHỈ CẦN SỬA ĐÚNG MỘT CHỖ** tại Composition Root
/// mà không làm ảnh hưởng đến bất kỳ dòng code nào ở tầng Domain hay Presentation.
Future<AppDependencies> buildDependencies({
  FailureSimulator? failureSimulatorOverride,
  DataSource<TransactionModel>? remoteDataSourceOverride,
  CacheDataSource<TransactionModel>? localDataSourceOverride,
  List<ErrorLogger>? loggersOverride,
  ErrorLogger? fileLoggerOverride,
  ErrorMessageMapper? messageMapperOverride,
  ErrorHandler? errorHandlerOverride,
  NonFatalErrorReporter? nonFatalReporterOverride,
  TransactionRepository? repositoryOverride,
  String Function()? idGeneratorOverride,
  DateTime Function()? clockOverride,
}) async {
  // 1. Khởi tạo/nhận FailureSimulator
  final FailureSimulator failureSimulator =
      failureSimulatorOverride ?? FailureSimulator();

  // 2. Lắp ráp hạ tầng ghi log và xử lý lỗi
  final ErrorLogger effectiveFileLogger = fileLoggerOverride ?? FileLogger();
  final List<ErrorLogger> effectiveLoggers = loggersOverride ??
      <ErrorLogger>[
        const ConsoleLogger(),
        effectiveFileLogger,
      ];
  final ErrorMessageMapper effectiveMapper =
      messageMapperOverride ?? const ErrorMessageMapper();

  final ErrorHandler effectiveHandler = errorHandlerOverride ??
      ErrorHandler(
        loggers: effectiveLoggers,
        messageMapper: effectiveMapper,
      );

  // 3. Nối NonFatalErrorReporter trực tiếp vào pipeline ErrorHandler
  final NonFatalErrorReporter effectiveReporter = nonFatalReporterOverride ??
      (Object error, StackTrace stack, {String? source}) {
        unawaited(
          effectiveHandler.handle(
            error,
            stack,
            source: source ?? 'RepositoryFallback',
          ),
        );
      };

  // 4. Lắp ráp các DataSources
  final DataSource<TransactionModel> effectiveRemote =
      remoteDataSourceOverride ??
          FakeRemoteDataSource(simulator: failureSimulator);

  final CacheDataSource<TransactionModel> effectiveLocal =
      localDataSourceOverride ??
          LocalDataSource(await SharedPreferences.getInstance());

  // 5. Lắp ráp TransactionRepository (Domain Interface hiện thực bởi Data Layer)
  final TransactionRepository effectiveRepo = repositoryOverride ??
      TransactionRepositoryImpl(
        remoteDataSource: effectiveRemote,
        localDataSource: effectiveLocal,
        nonFatalReporter: effectiveReporter,
      );

  // 6. Lắp ráp 6 UseCases độc lập của tầng Domain
  final GetTransactions getTransactions = GetTransactions(effectiveRepo);
  final GetTransactionById getTransactionById =
      GetTransactionById(effectiveRepo);
  final AddTransaction addTransaction = AddTransaction(
    effectiveRepo,
    idGenerator: idGeneratorOverride,
    clock: clockOverride,
  );
  final UpdateTransaction updateTransaction = UpdateTransaction(
    effectiveRepo,
    clock: clockOverride,
  );
  final DeleteTransaction deleteTransaction = DeleteTransaction(effectiveRepo);
  final GetSummary getSummary = GetSummary(effectiveRepo);

  return AppDependencies(
    failureSimulator: failureSimulator,
    remoteDataSource: effectiveRemote,
    localDataSource: effectiveLocal,
    loggers: effectiveLoggers,
    fileLogger: effectiveFileLogger,
    messageMapper: effectiveMapper,
    errorHandler: effectiveHandler,
    nonFatalReporter: effectiveReporter,
    repository: effectiveRepo,
    getTransactions: getTransactions,
    getTransactionById: getTransactionById,
    addTransaction: addTransaction,
    updateTransaction: updateTransaction,
    deleteTransaction: deleteTransaction,
    getSummary: getSummary,
  );
}
