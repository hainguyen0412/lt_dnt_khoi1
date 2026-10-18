import 'dart:developer' as developer;

import '../errors/app_exception.dart';
import 'error_logger.dart';
import 'log_entry.dart';

/// Bộ ghi log xuất dữ liệu trực tiếp ra Terminal / Debug Console của nhà phát triển.
///
/// **Lý do thiết kế:**
/// - Sử dụng `dart:developer.log` thay vì `print()` để không làm tràn output log khi release,
///   đồng thời tích hợp chuẩn xác với Dart DevTools (hỗ trợ lọc theo tên tag, level, stackTrace).
/// - [readAll] trả về danh sách rỗng và [clear] là no-op vì Console chỉ là luồng xuất
///   chuỗi một chiều (standard output stream) do IDE/hệ điều hành quản lý, không phải
///   là bộ nhớ lưu trữ có thể đọc lại hoặc xóa bằng code Dart.
class ConsoleLogger implements ErrorLogger {
  /// Khởi tạo một `ConsoleLogger`.
  const ConsoleLogger();

  @override
  Future<void> log(LogEntry entry) async {
    // Chuyển đổi Severity sang mã level chuẩn của logging framework (0-2000)
    final int level = _mapSeverityToLevel(entry.severity);

    developer.log(
      entry.message,
      name: entry.source ?? 'AppError',
      time: entry.timestamp,
      level: level,
      error: '${entry.errorType}(${entry.code}): ${entry.message}',
      stackTrace: entry.stackTrace != null
          ? StackTrace.fromString(entry.stackTrace!)
          : null,
    );
  }

  @override
  Future<List<LogEntry>> readAll() async {
    // Console là luồng xuất dữ liệu một chiều ra màn hình terminal,
    // không lưu trữ persistent trong bộ nhớ để truy vấn lại.
    return const <LogEntry>[];
  }

  @override
  Future<void> clear() async {
    // Không thể xóa nội dung đã in trên terminal/console thông qua API chuẩn của Dart.
  }

  int _mapSeverityToLevel(Severity severity) {
    return switch (severity) {
      Severity.info => 800, // Level INFO
      Severity.warning => 900, // Level WARNING
      Severity.error => 1000, // Level SEVERE
      Severity.critical => 1200, // Level SHOUT
    };
  }
}
