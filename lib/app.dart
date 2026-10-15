import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/di/app_dependencies.dart';
import 'core/error_handling/error_handler.dart';
import 'core/error_handling/error_logger.dart';
import 'core/simulation/failure_mode.dart';
import 'domain/repositories/transaction_repository.dart';
import 'domain/usecases/add_transaction.dart';
import 'domain/usecases/delete_transaction.dart';
import 'domain/usecases/get_summary.dart';
import 'domain/usecases/get_transaction_by_id.dart';
import 'domain/usecases/get_transactions.dart';
import 'domain/usecases/update_transaction.dart';
import 'presentation/screens/transaction_list_screen.dart';
import 'presentation/state/transaction_notifier.dart';

/// Widget gốc của ứng dụng Sổ chi tiêu cá nhân (Expense Tracker).
///
/// **Lý do thiết kế MultiProvider tại Root Widget:**
/// - Cung cấp toàn bộ các dependency đã được lắp ráp tại Composition Root (`AppDependencies`)
///   xuống toàn bộ cây widget thông qua cơ chế InheritedWidget tối ưu của `Provider`.
/// - Đăng ký [FailureSimulator] dưới dạng [ChangeNotifierProvider] để Settings/Debug Panel
///   có thể lắng nghe và điều khiển chế độ lỗi trực tiếp.
/// - Đăng ký [fileLogger] dưới dạng [Provider<ErrorLogger>] để màn hình Log Viewer (T-306)
///   ở Sprint 3 có thể truy xuất và xem lịch sử lỗi bền vững.
/// - Cung cấp độc lập từng UseCase giúp các View và Notifier ở Sprint 3 dễ dàng inject
///   đúng usecase cần thiết mà không phải phụ thuộc vòng tròn.
class ExpenseTrackerApp extends StatelessWidget {
  /// Đối tượng chứa toàn bộ các dependency đã được khởi tạo và lắp ráp.
  final AppDependencies dependencies;

  /// Khởi tạo [ExpenseTrackerApp] với [dependencies] bắt buộc.
  const ExpenseTrackerApp({
    super.key,
    required this.dependencies,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Trình điều khiển giả lập lỗi (lắng nghe và cập nhật UI khi đổi mode)
        ChangeNotifierProvider<FailureSimulator>.value(
          value: dependencies.failureSimulator,
        ),

        // 2. Repository Interface của tầng Domain
        Provider<TransactionRepository>.value(
          value: dependencies.repository,
        ),

        // 3. Bộ xử lý ngoại lệ tập trung (Centralized Error Pipeline)
        Provider<ErrorHandler>.value(
          value: dependencies.errorHandler,
        ),

        // 4. FileLogger phục vụ màn hình Log Viewer (T-306) ở Sprint 3
        Provider<ErrorLogger>.value(
          value: dependencies.fileLogger,
        ),

        // 5. Toàn bộ đối tượng AppDependencies
        Provider<AppDependencies>.value(
          value: dependencies,
        ),

        // 6. Danh sách 6 UseCases độc lập của Domain Layer
        Provider<GetTransactions>.value(
          value: dependencies.getTransactions,
        ),
        Provider<GetTransactionById>.value(
          value: dependencies.getTransactionById,
        ),
        Provider<AddTransaction>.value(
          value: dependencies.addTransaction,
        ),
        Provider<UpdateTransaction>.value(
          value: dependencies.updateTransaction,
        ),
        Provider<DeleteTransaction>.value(
          value: dependencies.deleteTransaction,
        ),
        Provider<GetSummary>.value(
          value: dependencies.getSummary,
        ),

        // 7. Quản lý trạng thái và điều phối nghiệp vụ giao dịch (T-301)
        ChangeNotifierProvider<TransactionNotifier>(
          create: (context) => TransactionNotifier(
            getTransactions: dependencies.getTransactions,
            getTransactionById: dependencies.getTransactionById,
            addTransaction: dependencies.addTransaction,
            updateTransaction: dependencies.updateTransaction,
            deleteTransaction: dependencies.deleteTransaction,
            getSummary: dependencies.getSummary,
            errorHandler: dependencies.errorHandler,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Sổ Chi Tiêu Cá Nhân',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const TransactionListScreen(),
      ),
    );
  }
}
