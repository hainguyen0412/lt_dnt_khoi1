import 'package:flutter/foundation.dart';

/// Chế độ giả lập lỗi kết nối và máy chủ phục vụ kiểm thử và demo phản biện.
enum FailureMode {
  /// Không giả lập lỗi (hoạt động bình thường).
  none,

  /// Lỗi mất kết nối mạng (SocketException).
  network,

  /// Lỗi quá thời gian chờ (TimeoutException).
  timeout,

  /// Lỗi máy chủ phản hồi mã lỗi 500 (HttpStatusError).
  server500,

  /// Dữ liệu JSON bị hỏng / sai lược đồ (ParseException).
  badJson,

  /// Chọn ngẫu nhiên một trong các lỗi trên hoặc thành công.
  random,
}

/// Lớp điều khiển trạng thái giả lập lỗi trong toàn ứng dụng.
///
/// **Lý do thiết kế:**
/// 1. Sử dụng [ChangeNotifier] từ `flutter/foundation.dart` giúp tầng Presentation (UI)
///    có thể lắng nghe sự thay đổi chế độ lỗi và cập nhật giao diện mà không cần phụ thuộc tầng Data.
/// 2. Đặt tại `lib/core/simulation/` nhằm cho phép tầng Presentation và Data cùng sử dụng
///    chung một trình điều khiển mô phỏng lỗi duy nhất (Shared Simulation State).
class FailureSimulator extends ChangeNotifier {
  FailureMode _mode;

  /// Khởi tạo [FailureSimulator] với chế độ ban đầu (mặc định là [FailureMode.none]).
  FailureSimulator([FailureMode initialMode = FailureMode.none])
      : _mode = initialMode;

  /// Chế độ giả lập lỗi hiện tại.
  FailureMode get mode => _mode;

  /// Cập nhật chế độ giả lập lỗi và thông báo cho các bên lắng nghe (Listeners).
  set mode(FailureMode value) {
    if (_mode != value) {
      _mode = value;
      notifyListeners();
    }
  }
}
