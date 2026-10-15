# HỢP ĐỒNG KIẾN TRÚC VÀ GIAO DIỆN HỆ THỐNG (CONTRACTS.MD)

> **Dự án:** Sổ Chi Tiêu Cá Nhân (Expense Tracker)  
> **Mục đích:** Đặc tả tường minh các bản hợp đồng giao tiếp (Interface Contracts) giữa các tầng kiến trúc và giữa hai thành viên phát triển:  
> - **Sinh viên A (Nguyễn Đức Hải):** Thiết kế Domain Logic, Cây ngoại lệ, Error Pipeline, State Notifier.  
> - **Sinh viên B (Phạm Nhung):** Triển khai Data Sources, Repository Implementation, UI Screens & Forms.  

---

## 1. HỢP ĐỒNG VẬN CHUYỂN DỮ LIỆU: `Result<T>` (R4, R6)
- **Đường dẫn định nghĩa:** `lib/core/utils/result.dart`
- **Mục đích hợp đồng:** Chuẩn hóa đầu ra của toàn bộ Repository và Use Case, thay thế hoàn toàn cơ chế `throw` ngoại lệ tùy tiện bằng kiểu dữ liệu hàm (functional programming).

```dart
sealed class Result<T> {
  const Result();

  /// Cho biết thao tác đã hoàn thành thành công hay chưa.
  bool get isSuccess;

  /// Cho biết thao tác có gặp thất bại hay không.
  bool get isFailure => !isSuccess;

  /// Rẽ nhánh xử lý dữ liệu [T] khi thành công hoặc [AppException] khi thất bại.
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(AppException error) onFailure,
  );

  /// Biến đổi dữ liệu thành công qua hàm [transform].
  Result<R> map<R>(R Function(T data) transform);

  /// Trả về dữ liệu [T] hoặc giá trị dự phòng từ hàm [orElse].
  T getOrElse(T Function(AppException error) orElse);
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
  @override
  bool get isSuccess => true;
  // ...
}

final class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
  @override
  bool get isSuccess => false;
  // ...
}
```

---

## 2. HỢP ĐỒNG CÂY NGOẠI LỆ HỆ THỐNG: `AppException` (R7, R9)
- **Đường dẫn định nghĩa:** `lib/core/errors/app_exception.dart` & `lib/core/errors/exception_factory.dart`
- **Mục đích hợp đồng:** Đóng kín (closed hierarchy) toàn bộ các loại lỗi có thể phát sinh trong ứng dụng thành 8 lớp con, hỗ trợ exhaustive pattern matching.

```dart
sealed class AppException implements Exception {
  final String message;
  final String code;
  final Severity severity;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    required this.code,
    required this.severity,
    this.originalError,
    this.stackTrace,
  });

  /// Factory chuyển đổi lỗi thô thành AppException tương ứng.
  factory AppException.from(Object error, [StackTrace? st]) =>
      ExceptionFactory.from(error, st);
}
```

### 8 Lớp con cụ thể trong hợp đồng:
1. `NetworkException`: Lỗi kết nối mạng, socket đường truyền (`NETWORK_ERROR`, warning).
2. `RequestTimeoutException`: Quá hạn kết nối mạng/async (`TIMEOUT_ERROR`, warning).
3. `ServerException`: Lỗi mã phản hồi từ máy chủ 4xx/5xx (`SERVER_ERROR`, error/warning).
4. `ParseException`: Lỗi định dạng JSON hoặc ép kiểu dữ liệu (`PARSE_ERROR`, error).
5. `CacheException`: Lỗi đọc/ghi bộ nhớ đệm cục bộ disk I/O (`CACHE_ERROR`, error).
6. `ValidationException`: Vi phạm quy tắc ràng buộc nghiệp vụ (`VALIDATION_ERROR`, info).
7. `NotFoundException`: Không tìm thấy bản ghi theo ID (`NOT_FOUND`, info).
8. `UnknownException`: Các lỗi runtime không xác định còn lại (`UNKNOWN_ERROR`, critical).

---

## 3. HỢP ĐỒNG KHO DỮ LIỆU: `TransactionRepository` (R6)
- **Đường dẫn định nghĩa:** `lib/domain/repositories/transaction_repository.dart`
- **Đơn vị hiện thực:** `TransactionRepositoryImpl` (`lib/data/repositories/transaction_repository_impl.dart`)
- **Mục đích hợp đồng:** Cách ly hoàn toàn tầng Domain khỏi nguồn dữ liệu (In-Memory, Local Cache, REST API).

```dart
abstract interface class TransactionRepository {
  /// Lấy toàn bộ danh sách giao dịch (hỗ trợ tự động fallback sang local cache nếu mất mạng).
  Future<Result<List<Transaction>>> getAll();

  /// Lấy chi tiết một giao dịch theo định danh [id].
  Future<Result<Transaction>> getById(String id);

  /// Thêm mới một [transaction] đã qua thẩm định nghiệp vụ vào kho lưu trữ.
  Future<Result<Transaction>> add(Transaction transaction);

  /// Cập nhật thông tin của một [transaction] đã tồn tại.
  Future<Result<Transaction>> update(Transaction transaction);

  /// Xóa vĩnh viễn giao dịch theo [id].
  Future<Result<void>> delete(String id);

  /// Lấy thông tin thống kê tài chính tổng quan (Tổng thu, Tổng chi, Số dư khả dụng).
  Future<Result<TransactionSummary>> getSummary();
}
```

---

## 4. HỢP ĐỒNG GHI NHẬT KÝ LỖI: `ErrorLogger` (R11)
- **Đường dẫn định nghĩa:** `lib/core/error_handling/error_logger.dart`
- **Đơn vị hiện thực:** `FileLogger` (`lib/core/error_handling/file_logger.dart`) & `ConsoleLogger` (`lib/core/error_handling/console_logger.dart`)
- **Mục đích hợp đồng:** Định nghĩa giao diện trừu tượng để Pipeline đẩy log ra các đích khác nhau (Console, File đĩa, Crashlytics) mà không gây rò rỉ ngoại lệ.

```dart
abstract interface class ErrorLogger {
  /// Ghi một bản ghi nhật ký [entry] vào hệ thống lưu trữ đích.
  /// Cam kết: Không bao giờ được ném ngoại lệ ra ngoài luồng gọi.
  Future<void> log(LogEntry entry);

  /// Đọc toàn bộ danh sách các bản ghi lỗi hiện có (xếp từ mới nhất đến cũ nhất).
  Future<List<LogEntry>> readAll();

  /// Xóa sạch toàn bộ lịch sử bản ghi lỗi.
  Future<void> clear();
}
```

---

## 5. HỢP ĐỒNG ĐIỂM VÀO XỬ LÝ LỖI TẬP TRUNG: `ErrorHandler.handle` (R11)
- **Đường dẫn định nghĩa:** `lib/core/error_handling/error_handler.dart`
- **Mục đích hợp đồng:** Điểm tiếp nhận duy nhất toàn bộ lỗi của ứng dụng từ Presentation và Global Safety Net.

```dart
class ErrorHandler {
  /// Điểm vào duy nhất tiếp nhận mọi ngoại lệ phát sinh trong hệ thống.
  /// 
  /// Thực thi tuần tự 5 bước: Normalize -> Classify -> Log -> Decide Retry -> Translate.
  /// Cam kết tuyệt đối: KHÔNG BAO GIỜ ném ngoại lệ ra ngoài, luôn trả về [UserFacingError] an toàn.
  Future<UserFacingError> handle(
    Object error,
    StackTrace st, {
    String? source,
  });
}
```

---

## 6. HỢP ĐỒNG QUẢN LÝ TRẠNG THÁI GIAO DIỆN: `TransactionListState` (R8, R10)
- **Đường dẫn định nghĩa:** `lib/presentation/state/transaction_state.dart`
- **Mục đích hợp đồng:** Phân tách trạng thái danh sách toàn màn hình (Sealed Class) với các cờ thao tác form cục bộ trong `TransactionNotifier`.

```dart
sealed class TransactionListState {
  const TransactionListState();
}

/// Trạng thái khởi tạo ban đầu khi chưa tải dữ liệu.
final class TransactionListInitial extends TransactionListState {
  const TransactionListInitial();
}

/// Trạng thái đang tải dữ liệu (hiển thị Shimmer / Spinner).
final class TransactionListLoading extends TransactionListState {
  const TransactionListLoading();
}

/// Trạng thái tải dữ liệu thành công có ít nhất 1 bản ghi.
final class TransactionListLoaded extends TransactionListState {
  final List<Transaction> items;
  final TransactionSummary summary;
  const TransactionListLoaded({required this.items, required this.summary});
}

/// Trạng thái kho dữ liệu hoàn toàn rỗng (0 giao dịch).
final class TransactionListEmpty extends TransactionListState {
  const TransactionListEmpty();
}

/// Trạng thái tải danh sách thất bại (lưu trữ previousItems/previousSummary để graceful degradation).
final class TransactionListError extends TransactionListState {
  final UserFacingError error;
  final List<Transaction>? previousItems;
  final TransactionSummary? previousSummary;
  const TransactionListError({
    required this.error,
    this.previousItems,
    this.previousSummary,
  });
}
```

---

*Toàn bộ 6 bản hợp đồng trên đã được cả hai thành viên nhóm tuân thủ 100% trong suốt quá trình phát triển dự án.*
