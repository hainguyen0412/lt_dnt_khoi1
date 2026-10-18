import 'package:flutter/material.dart';

import '../../presentation/widgets/error_view.dart';
import '../errors/app_exception.dart';
import 'user_facing_error.dart';

/// Cài đặt trình dựng widget lỗi mặc định [ErrorWidget.builder] cho toàn bộ ứng dụng (R10).
///
/// **Lý do kiến trúc & Ranh giới trách nhiệm (R10):**
/// - Khi một widget ném ngoại lệ trong quá trình thực thi phương thức `build()`, Flutter
///   sẽ kích hoạt [ErrorWidget.builder] để hiển thị giao diện thay thế, loại bỏ hoàn toàn
///   hiện tượng sập ứng dụng ra "màn hình đỏ" (Red Screen of Death) trong debug hoặc màn hình xám trong release.
/// - **QUAN TRỌNG VỀ GHI LOG (Tránh duplicate log):**
///   Hàm này **CHỈ VẼ GIAO DIỆN (UI)**, tuyệt đối **KHÔNG GHI LOG**.
///   Lý do: Trước khi gọi [ErrorWidget.builder], Flutter Framework luôn luôn gửi sự kiện lỗi này
///   tới `FlutterError.onError` (đã được bắt và chuyển tới `ErrorHandler` tại T-205 qua `GlobalErrorHooks`).
///   Nếu tại đây tiếp tục gọi logger, một lỗi render sẽ bị ghi 2 lần vào file nhật ký.
/// - Giao diện hiển thị: Sử dụng [ErrorView.compact] với thông điệp an toàn:
///   *"Màn hình gặp sự cố khi hiển thị. Hãy quay lại và thử lại."*
///   và `canRetry: false` (không có nút Thử lại) vì lỗi render giao diện cần người dùng điều hướng
///   hoặc tải lại luồng thay vì bấm retry cục bộ.
void installErrorWidgetBuilder() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      type: MaterialType.transparency,
      child: Center(
        child: ErrorView.compact(
          error: UserFacingError(
            message:
                'Màn hình gặp sự cố khi hiển thị. Hãy quay lại và thử lại.',
            canRetry: false,
            severity: Severity.error,
          ),
        ),
      ),
    );
  };
}
