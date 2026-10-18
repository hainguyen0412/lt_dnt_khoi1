/// Ngoại lệ thô đại diện cho mã phản hồi HTTP từ tầng network/data client.
///
/// Lớp này được thiết kế như một đối tượng lỗi tầng thấp (raw error).
/// Tầng data sẽ ném lỗi này và ExceptionFactory sẽ bắt, chuyển đổi thành
/// `NotFoundException` (nếu 404) hoặc `ServerException` (cho các mã khác).
class HttpStatusError implements Exception {
  /// Mã trạng thái HTTP (ví dụ: 400, 404, 500).
  final int statusCode;

  /// Thông điệp lỗi kỹ thuật đi kèm từ máy chủ (nếu có).
  final String? message;

  /// Khởi tạo một đối tượng lỗi HTTP với [statusCode] và [message] tùy chọn.
  const HttpStatusError(this.statusCode, [this.message]);

  @override
  String toString() {
    if (message != null && message!.isNotEmpty) {
      return 'HttpStatusError($statusCode): $message';
    }
    return 'HttpStatusError($statusCode)';
  }
}
