import 'dart:async';

import '../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../entities/transaction_summary.dart';

/// Giao diện trừu tượng (Interface) định nghĩa các thao tác dữ liệu với giao dịch thu - chi.
///
/// **HỢP ĐỒNG KỸ THUẬT BẮT BUỘC (CONTRACT):**
/// 1. TẤT CẢ các phương thức trong Repository đều trả về `Future<Result<...>>`.
/// 2. **Repository KHÔNG BAO GIỜ ném ngoại lệ (Exception) ra ngoài luồng điều khiển.**
///    Mọi lỗi từ tầng thấp (Network, Timeout, Server, Cache IO, Parse...) phải được bắt lại
///    và chuyển đổi thành `Result.failure(AppException)`.
/// 3. Việc phân tách interface này tại tầng Domain tuân thủ **Dependency Inversion Principle (DIP)**:
///    Tầng Domain chỉ định nghĩa nhu cầu dữ liệu; việc cài đặt chi tiết (`TransactionRepositoryImpl`)
///    nằm hoàn toàn ở tầng Data.
abstract interface class TransactionRepository {
  /// Lấy toàn bộ danh sách các giao dịch đã ghi nhận.
  ///
  /// Trả về [Success] chứa danh sách [Transaction] nếu thành công,
  /// hoặc [Failure] chứa [AppException] nếu xảy ra lỗi đọc dữ liệu.
  Future<Result<List<Transaction>>> getAll();

  /// Tra cứu chi tiết một giao dịch cụ thể theo [id].
  ///
  /// Trả về [Success] chứa [Transaction], hoặc [Failure] chứa [NotFoundException]
  /// nếu bản ghi không tồn tại.
  Future<Result<Transaction>> getById(String id);

  /// Thêm mới một giao dịch [transaction] vào hệ thống lưu trữ.
  ///
  /// Trả về [Success] chứa [Transaction] đã được lưu thành công,
  /// hoặc [Failure] nếu phát sinh lỗi mạng hoặc lưu trữ.
  Future<Result<Transaction>> add(Transaction transaction);

  /// Cập nhật thông tin của một giao dịch [transaction] đã tồn tại.
  ///
  /// Trả về [Success] chứa [Transaction] sau khi cập nhật,
  /// hoặc [Failure] nếu bản ghi không tồn tại hoặc lỗi ghi dữ liệu.
  Future<Result<Transaction>> update(Transaction transaction);

  /// Xóa vĩnh viễn một giao dịch khỏi hệ thống theo [id].
  ///
  /// Sử dụng kiểu generic [Result<void>] vì thao tác xóa không trả về thực thể dữ liệu.
  Future<Result<void>> delete(String id);

  /// Tính toán và lấy thông tin tổng hợp tài chính (Tổng thu, Tổng chi, Số dư).
  ///
  /// Trả về [Success] chứa [TransactionSummary], hoặc [Failure] nếu xảy ra lỗi.
  Future<Result<TransactionSummary>> getSummary();
}
