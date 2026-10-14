import 'dart:developer' as developer;

/// Mixin cung cấp khả năng ghi log hoạt động kỹ thuật cho các lớp trong hệ thống.
///
/// **Lý do thiết kế:**
/// 1. Tái sử dụng mã nguồn (Code reuse): Bất kỳ class nào (Repository, DataSource, Provider)
///    cần theo dõi hành vi nội bộ đều có thể gắn mixin này mà không cần lặp lại việc gọi `developer.log`.
/// 2. Độc lập với `ErrorLogger`: Mixin này ghi trực tiếp ra console của Dart Developer Tools
///    qua `dart:developer log()`, không phụ thuộc vào `ErrorLogger` hay tầng Error Handling,
///    giúp loại bỏ hoàn toàn nguy cơ phụ thuộc vòng (circular dependency).
mixin LoggableMixin {
  /// Nhãn định danh nguồn gốc của log.
  ///
  /// Mặc định trả về tên lớp thực thi ([runtimeType]). Các lớp con có thể ghi đè
  /// getter này nếu muốn gán tag tùy biến để dễ dàng lọc trên DevTools.
  String get logTag => runtimeType.toString();

  /// Ghi log ở mức độ gỡ lỗi (Debug / Level 500).
  void logDebug(String message) {
    developer.log(
      message,
      name: logTag,
      level: 500,
    );
  }

  /// Ghi log ở mức độ thông tin thông thường (Info / Level 800).
  void logInfo(String message) {
    developer.log(
      message,
      name: logTag,
      level: 800,
    );
  }

  /// Ghi log ở mức độ cảnh báo (Warning / Level 900).
  void logWarning(String message) {
    developer.log(
      message,
      name: logTag,
      level: 900,
    );
  }
}
