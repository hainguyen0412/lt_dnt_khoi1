import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/error_handling/user_facing_error.dart';
import 'error_view.dart';

/// Widget ranh giới lỗi (Error Boundary) cấp độ màn hình (T-304, R10).
///
/// **Lý do kiến trúc & Ranh giới trách nhiệm:**
/// - **Không có try-catch bao widget con trong Flutter:** Khác với `componentDidCatch`
///   của React, Flutter không hỗ trợ bắt exception phát sinh trong widget con bằng khối try-catch thông thường.
///   Do đó, Error Boundary trong ứng dụng này được hiện thực theo 2 lớp thực tế:
///   1. Lớp bắt lỗi render lúc `build()`: do `ErrorWidget.builder` (xem [installErrorWidgetBuilder])
///      thay thế bằng [ErrorView.compact].
///   2. Lớp bảo vệ trạng thái màn hình: [ErrorBoundary] nhận một [ValueListenable] phát tín hiệu
///      lỗi nghiêm trọng từ ViewModel/Notifier ([errorSource]).
/// - **Phân tách ranh giới với SnackBar (R10):**
///   - [ErrorBoundary] chỉ kích hoạt khi phát sinh lỗi nghiêm trọng cấp màn hình (ví dụ: bug bất ngờ
///     ở tầng dưới khiến luồng xử lý bị vỡ, được bọc trong khối `_run` của `TransactionNotifier`
///     và đẩy vào `boundaryError`).
///   - Các lỗi thao tác thông thường (validation lỗi, lỗi mạng tạm thời khi bấm Lưu) vẫn được gửi
///     qua `actionError` để hiển thị [SnackBar], **tuyệt đối không kích hoạt ErrorBoundary** nhằm
///     tránh làm mất dữ liệu người dùng đang nhập dở trên Form.
///   - Các lỗi bất đồng bộ nằm ngoài cây widget do `GlobalErrorHooks` bắt.
/// - **Hành vi hiển thị:**
///   - Khi [errorSource] chứa lỗi: Hiển thị [ErrorView] đầy đủ thay thế cho [child]. Nếu lỗi cho phép
///     thử lại (`canRetry == true`), người dùng có thể bấm nút "Thử lại" để gọi [onRetry].
///   - Nếu có truyền [onDismiss], giao diện cung cấp thêm nút bỏ qua để gọi [onDismiss].
///   - Khi [errorSource] được xóa về `null`: Tự động khôi phục và hiển thị lại [child].
class ErrorBoundary extends StatelessWidget {
  /// Widget con được bảo vệ bên trong ranh giới lỗi.
  final Widget child;

  /// Nguồn phát tín hiệu lỗi cấp ranh giới (ví dụ: `TransactionNotifier.boundaryError`).
  final ValueListenable<UserFacingError?> errorSource;

  /// Callback thực thi khi người dùng bấm nút "Thử lại" trên giao diện lỗi.
  final VoidCallback onRetry;

  /// Callback thực thi khi người dùng bấm nút bỏ qua / đóng thông báo lỗi (tùy chọn).
  final VoidCallback? onDismiss;

  /// Khởi tạo [ErrorBoundary].
  const ErrorBoundary({
    super.key,
    required this.child,
    required this.errorSource,
    required this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserFacingError?>(
      valueListenable: errorSource,
      builder: (context, error, childWidget) {
        if (error != null) {
          return ErrorView(
            error: error,
            onRetry: onRetry,
            onDismiss: onDismiss,
          );
        }
        return childWidget!;
      },
      child: child,
    );
  }
}
