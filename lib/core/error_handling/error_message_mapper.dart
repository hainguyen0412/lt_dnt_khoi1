import '../errors/app_exception.dart';

/// Lớp ánh xạ từ [AppException] kỹ thuật sang thông điệp tiếng Việt thân thiện với người dùng.
///
/// **Lý do thiết kế:**
/// - **Tách biệt mối quan tâm (Separation of Concerns):**
///   - [AppException] và các DataSource chứa thông điệp lỗi kỹ thuật (bằng tiếng Anh,
///     chứa stack trace, mã lỗi) phục vụ cho developer chẩn đoán sự cố.
///   - [ErrorMessageMapper] đóng vai trò bộ chuyển đổi ngôn ngữ (Translator), biến các lỗi
///     kỹ thuật đó thành câu thông báo tiếng Việt dễ hiểu, lịch sự, không làm người dùng
///     bối rối hoặc để lộ thông tin bảo mật của hệ thống.
/// - **Exhaustive Pattern Matching (R9):**
///   - Sử dụng cú pháp `switch` expression trên `sealed class AppException`. Nhờ tính chất
///     đóng của `sealed class`, Dart 3 bắt buộc phải xử lý vét cạn đủ mọi lớp con. Nếu sau này
///     thêm loại exception mới mà quên khai báo ánh xạ, code sẽ báo lỗi ngay khi compile.
/// - **Dependency Injection (T-204):**
///   - Cung cấp `const ErrorMessageMapper()` và phương thức [messageFor] dạng instance method
///     để có thể tiêm (inject) linh hoạt vào `ErrorHandler` ở T-204 và dễ dàng thay thế/mocking.
class ErrorMessageMapper {
  /// Khởi tạo một đối tượng [ErrorMessageMapper].
  const ErrorMessageMapper();

  /// Chuyển đổi một [AppException] thành câu thông báo tiếng Việt thân thiện.
  String messageFor(AppException e) {
    return switch (e) {
      NetworkException() =>
        'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
      RequestTimeoutException() =>
        'Máy chủ phản hồi quá chậm. Vui lòng thử lại.',
      ServerException(:final isServerError) => isServerError
          ? 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'
          : 'Yêu cầu không hợp lệ.',
      ParseException() => 'Dữ liệu nhận về không đúng định dạng.',
      CacheException() => 'Không đọc được dữ liệu lưu trên máy.',
      ValidationException(:final message) => message,
      NotFoundException() => 'Không tìm thấy dữ liệu yêu cầu.',
      UnknownException() => 'Đã xảy ra lỗi không xác định.',
    };
  }
}
