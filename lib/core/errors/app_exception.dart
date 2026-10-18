import 'exception_factory.dart';

/// Mức độ nghiêm trọng của lỗi trong hệ thống.
///
/// Được dùng trong toàn bộ pipeline xử lý lỗi để quyết định cách ghi log,
/// cách hiển thị thông báo và điều hướng giao diện phù hợp.
enum Severity {
  /// Lỗi mức thông tin (ví dụ: dữ liệu form không hợp lệ, không tìm thấy item).
  info,

  /// Cảnh báo (ví dụ: mất kết nối tạm thời, timeout, lỗi 4xx từ máy chủ).
  warning,

  /// Lỗi hệ thống nghiêm trọng (ví dụ: máy chủ 500, hỏng cache, lỗi định dạng dữ liệu).
  error,

  /// Lỗi nghiêm trọng nhất, đe dọa sự ổn định ứng dụng (ví dụ: lỗi runtime chưa xác định).
  critical,
}

/// Lớp cơ sở trừu tượng đại diện cho mọi ngoại lệ nghiệp vụ của ứng dụng.
///
/// **Lý do thiết kế `sealed class` (Dart 3.x):**
/// 1. Tính đóng (Closed hierarchy): Toàn bộ các lớp con phải được khai báo trong cùng thư viện,
///    ngăn chặn các tầng khác tùy tiện kế thừa ngoại lệ ngoài tầm kiểm soát.
/// 2. Exhaustive pattern matching: Trình biên dịch Dart sẽ bắt buộc mọi biểu thức `switch`
///    phải xử lý đầy đủ tất cả các trường hợp lớp con của `AppException`. Nếu sau này có thêm
///    loại ngoại lệ mới, trình biên dịch sẽ báo lỗi ngay lập tức nếu thiếu `case`,
///    giúp loại bỏ hoàn toàn nguy cơ sót trường hợp xử lý lỗi khi bảo trì.
sealed class AppException implements Exception {
  /// Thông điệp kỹ thuật tóm tắt nguyên nhân lỗi (bằng tiếng Anh).
  final String message;

  /// Mã định danh lỗi chuẩn hóa phục vụ phân loại và tra cứu (ví dụ: NETWORK_ERROR).
  final String code;

  /// Mức độ nghiêm trọng của ngoại lệ.
  final Severity severity;

  /// Đối tượng lỗi gốc ban đầu (nếu có), dùng để debug hoặc truy vết.
  final Object? originalError;

  /// Vết ngăn xếp (stack trace) tại thời điểm phát sinh ngoại lệ.
  final StackTrace? stackTrace;

  /// Khởi tạo một đối tượng [AppException].
  const AppException({
    required this.message,
    required this.code,
    required this.severity,
    this.originalError,
    this.stackTrace,
  });

  /// Factory chuyển đổi một lỗi thô ([error]) thành [AppException] đúng loại.
  ///
  /// Hàm ủy quyền toàn bộ logic phân tích và ánh xạ cho [ExceptionFactory.from].
  /// Việc ủy thác này tuân thủ Factory Pattern và nguyên lý Single Responsibility (SRP):
  /// `AppException` chỉ chứa cấu trúc dữ liệu lỗi, còn `ExceptionFactory` đảm nhiệm
  /// toàn bộ logic ánh xạ phức tạp từ các lỗi tầng thấp.
  factory AppException.from(Object error, [StackTrace? st]) =>
      ExceptionFactory.from(error, st);

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Ngoại lệ mất kết nối mạng hoặc lỗi socket đường truyền.
final class NetworkException extends AppException {
  /// Khởi tạo [NetworkException] với mã `NETWORK_ERROR` và mức độ [Severity.warning].
  const NetworkException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'NETWORK_ERROR',
          severity: Severity.warning,
        );
}

/// Ngoại lệ quá thời gian chờ yêu cầu (timeout).
///
/// Đặt tên là [RequestTimeoutException] để tránh trùng lặp với `TimeoutException`
/// có sẵn trong thư viện chuẩn `dart:async`.
final class RequestTimeoutException extends AppException {
  /// Khởi tạo [RequestTimeoutException] với mã `REQUEST_TIMEOUT` và mức độ [Severity.warning].
  const RequestTimeoutException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'REQUEST_TIMEOUT',
          severity: Severity.warning,
        );
}

/// Ngoại lệ phản hồi lỗi từ máy chủ kèm mã HTTP status code.
final class ServerException extends AppException {
  /// Mã trạng thái HTTP trả về từ server (ví dụ: 400, 500, 503).
  final int statusCode;

  /// Khởi tạo [ServerException] với mã `SERVER_ERROR`.
  ///
  /// Mức độ nghiêm trọng [severity] tự động được đánh giá:
  /// - [Severity.error]: nếu [statusCode] >= 500 (lỗi máy chủ nội bộ).
  /// - [Severity.warning]: nếu [statusCode] thuộc dải 4xx (lỗi phía client).
  ServerException({
    required super.message,
    required this.statusCode,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'SERVER_ERROR',
          severity: statusCode >= 500 ? Severity.error : Severity.warning,
        );

  /// Cho biết mã lỗi có thuộc nhóm lỗi client (4xx) hay không.
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Cho biết mã lỗi có thuộc nhóm lỗi server (5xx) hay không.
  bool get isServerError => statusCode >= 500 && statusCode < 600;
}

/// Ngoại lệ phân tích cú pháp hoặc giải mã dữ liệu (parse/format error).
final class ParseException extends AppException {
  /// Khởi tạo [ParseException] với mã `PARSE_ERROR` và mức độ [Severity.error].
  const ParseException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'PARSE_ERROR',
          severity: Severity.error,
        );
}

/// Ngoại lệ thao tác với bộ nhớ lưu trữ cục bộ/cache (đọc/ghi file, SharedPreferences).
final class CacheException extends AppException {
  /// Khởi tạo [CacheException] với mã `CACHE_ERROR` và mức độ [Severity.error].
  const CacheException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'CACHE_ERROR',
          severity: Severity.error,
        );
}

/// Ngoại lệ dữ liệu không vượt qua quy tắc kiểm tra tính hợp lệ (validation).
final class ValidationException extends AppException {
  /// Tên trường dữ liệu vi phạm ràng buộc (nếu có).
  final String? field;

  /// Khởi tạo [ValidationException] với mã `VALIDATION_ERROR` và mức độ [Severity.info].
  const ValidationException({
    required super.message,
    this.field,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'VALIDATION_ERROR',
          severity: Severity.info,
        );
}

/// Ngoại lệ không tìm thấy tài nguyên yêu cầu (ví dụ: HTTP 404 hoặc ID không tồn tại).
final class NotFoundException extends AppException {
  /// Khởi tạo [NotFoundException] với mã `NOT_FOUND` và mức độ [Severity.info].
  const NotFoundException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'NOT_FOUND',
          severity: Severity.info,
        );
}

/// Ngoại lệ không xác định hoặc lỗi lập trình chưa được xử lý cụ thể.
final class UnknownException extends AppException {
  /// Khởi tạo [UnknownException] với mã `UNKNOWN_ERROR` và mức độ [Severity.critical].
  const UnknownException({
    required super.message,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'UNKNOWN_ERROR',
          severity: Severity.critical,
        );
}
