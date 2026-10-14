/// Ngoại lệ thô đại diện cho lỗi phát sinh khi thao tác lưu trữ bộ nhớ đệm (cache/local storage).
///
/// Lớp này đóng vai trò ngoại lệ tầng thấp (raw error) được ném ra từ các DataSource
/// lưu trữ cục bộ (ví dụ: SharedPreferences, file I/O). `ExceptionFactory` sẽ nhận diện
/// lỗi này và chuyển đổi thành `CacheException` chuẩn của hệ thống.
class CacheStorageError implements Exception {
  /// Thông điệp mô tả lỗi thao tác bộ nhớ đệm.
  final String message;

  /// Nguyên nhân gốc rễ gây ra lỗi (nếu có, ví dụ exception từ disk I/O).
  final Object? cause;

  /// Khởi tạo một lỗi lưu trữ cache với [message] và [cause] tùy chọn.
  const CacheStorageError(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'CacheStorageError: $message (Cause: $cause)';
    }
    return 'CacheStorageError: $message';
  }
}
