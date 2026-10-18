import '../errors/app_exception.dart';

/// Đại diện cho đối tượng lỗi an toàn đã được xử lý để hiển thị trực tiếp cho người dùng cuối.
///
/// **Lý do thiết kế:**
/// - **Đóng gói an toàn (Information Hiding):** Tầng Presentation (UI) tuyệt đối không
///   nên tiếp xúc trực tiếp với các ngoại lệ kỹ thuật, mã lỗi nội bộ hay stack trace.
///   [UserFacingError] chỉ cung cấp đúng 3 thông tin cần thiết:
///   1. [message]: Câu thông báo tiếng Việt lịch sự, dễ hiểu.
///   2. [canRetry]: Quyết định xem UI có nên hiển thị nút "Thử lại" (Retry) hay không.
///   3. [severity]: Mức độ nghiêm trọng để UI chọn cách thể hiện phù hợp (SnackBar cho info/warning,
///      Dialog hoặc ErrorView toàn màn hình cho error/critical).
/// - **Bất biến (Immutability):** Cung cấp `const constructor` giúp tái sử dụng và tối ưu hiệu năng.
class UserFacingError {
  /// Câu thông điệp tiếng Việt thân thiện gửi tới người dùng.
  final String message;

  /// Cho biết người dùng có thể thực hiện lại thao tác vừa thất bại hay không.
  final bool canRetry;

  /// Mức độ nghiêm trọng của lỗi phục vụ lựa chọn phong cách hiển thị trên UI.
  final Severity severity;

  /// Khởi tạo một [UserFacingError] bất biến.
  const UserFacingError({
    required this.message,
    required this.canRetry,
    required this.severity,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserFacingError &&
        other.message == message &&
        other.canRetry == canRetry &&
        other.severity == severity;
  }

  @override
  int get hashCode => Object.hash(message, canRetry, severity);

  @override
  String toString() {
    return 'UserFacingError(severity: ${severity.name}, canRetry: $canRetry, message: "$message")';
  }
}
