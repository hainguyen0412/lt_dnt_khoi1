import 'log_entry.dart';

/// Hợp đồng trừu tượng định nghĩa khả năng ghi và truy xuất nhật ký lỗi hệ thống.
///
/// **Lý do thiết kế Interface Pattern:**
/// Tách rời hành vi ghi log khỏi phương tiện lưu trữ cụ thể (Console, File, hay
/// Remote Service trong tương lai). Giúp tầng `ErrorHandler` chỉ phụ thuộc vào
/// abstraction [ErrorLogger], hỗ trợ Dependency Injection và dễ dàng mock trong Unit Test.
///
/// **Quy ước hợp đồng:**
/// Mọi implementation của [ErrorLogger] cam kết **KHÔNG BAO GIỜ** ném ngoại lệ
/// ra ngoài để bảo vệ tính ổn định của ứng dụng.
abstract interface class ErrorLogger {
  /// Ghi một bản ghi nhật ký lỗi [entry].
  Future<void> log(LogEntry entry);

  /// Đọc toàn bộ các bản ghi nhật ký lỗi đã lưu (nếu phương tiện hỗ trợ).
  ///
  /// Danh sách trả về được sắp xếp theo thứ tự thời gian mới nhất lên đầu.
  Future<List<LogEntry>> readAll();

  /// Xóa toàn bộ nhật ký lỗi đã lưu trữ.
  Future<void> clear();
}
