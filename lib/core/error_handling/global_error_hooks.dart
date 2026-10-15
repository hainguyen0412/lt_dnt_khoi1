import 'dart:async';

import 'package:flutter/foundation.dart';

import 'error_handler.dart';

/// Lớp thiết lập hệ thống lưới an toàn 3 lớp toàn cục (3-tier Global Safety Net) cho ứng dụng.
///
/// **Lý do kiến trúc & Vì sao cần cả 3 lớp lưới an toàn (R10, R11):**
/// Một ứng dụng Flutter hiện đại chịu ảnh hưởng bởi nhiều luồng thực thi khác nhau:
/// 1. **Lớp 1 - `FlutterError.onError` (Lỗi tầng Framework/Widget):**
///    - Bắt các ngoại lệ phát sinh bên trong vòng đời widget của Flutter (ví dụ: lỗi trong phương thức
///      `build()`, lỗi layout overflow, lỗi render pipeline).
///    - Nếu không bắt, Flutter sẽ vẽ "màn hình đỏ" (Red Screen of Death) trong debug hoặc màn hình xám trong release.
///    - Trong debug mode (`kDebugMode`), ta gọi thêm `FlutterError.presentError(details)` để giữ nguyên
///      trải nghiệm gỡ lỗi chuẩn trên console/IDE của nhà phát triển.
///
/// 2. **Lớp 2 - `PlatformDispatcher.instance.onError` (Lỗi bất đồng bộ cấp Engine/Platform):**
///    - Bắt các ngoại lệ bất đồng bộ (unhandled asynchronous errors) phát sinh bên ngoài cây widget
///      (ví dụ: lỗi trong callback Timer, unhandled microtasks, hoặc ngoại lệ từ Platform Channels).
///    - Callback này **BẮT BUỘC PHẢI `return true;`** để báo cho Flutter Engine biết lỗi đã được
///      xử lý an toàn, ngăn không cho hệ điều hành (Android/iOS) force-close (crash) tiến trình ứng dụng.
///
/// 3. **Lớp 3 - `runGuarded` với `runZonedGuarded` (Lưới an toàn cấp Zone):**
///    - Thiết lập một Zone biệt lập bọc toàn bộ ứng dụng từ thời điểm khởi động. Bắt các lỗi async
///      lọt lưới trong Zone mà `PlatformDispatcher` có thể không nắm bắt được trong một số môi trường cô lập.
///    - Đảm bảo `WidgetsFlutterBinding.ensureInitialized()` và `runApp()` thực thi trong CÙNG MỘT Zone
///      để loại trừ triệt để lỗi "Zone mismatch".
///
/// **Điểm đến tập trung:**
/// Toàn bộ lỗi từ cả 3 lớp đều được đẩy vào `handler.handle(error, stack, source: 'global')`.
/// Tại đây, `ErrorHandler` sẽ tự động kích hoạt cơ chế nâng mức độ nghiêm trọng lên tối thiểu `error`
/// vì đây là lỗi đã lọt qua các ranh giới xử lý tại chỗ.
class GlobalErrorHooks {
  // Utility class chứa static methods, ẩn constructor mặc định
  const GlobalErrorHooks._();

  /// Đăng ký hai lớp lưới an toàn `FlutterError.onError` và `PlatformDispatcher.instance.onError`.
  static void install(ErrorHandler handler) {
    // Lớp 1: Bắt lỗi trong quá trình build, layout, render của Flutter Framework
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
      unawaited(
        handler.handle(
          details.exception,
          details.stack ?? StackTrace.current,
          source: 'global',
        ),
      );
    };

    // Lớp 2: Bắt lỗi bất đồng bộ lọt ra ngoài framework ở cấp Engine/Isolate
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(
        handler.handle(
          error,
          stack,
          source: 'global',
        ),
      );
      // Trả về true để xác nhận lỗi đã được xử lý, ngăn chặn crash process
      return true;
    };
  }

  /// Khởi chạy ứng dụng [body] bên trong một Zone an toàn được bảo vệ bởi [runZonedGuarded].
  ///
  /// Lớp lưới an toàn thứ 3 này sẽ bắt mọi lỗi async unhandled phát sinh trong Zone.
  static void runGuarded(
    Future<void> Function() body,
    ErrorHandler handler,
  ) {
    runZonedGuarded<Future<void>>(
      () async {
        // Cài đặt các hooks toàn cục ngay trong Zone của ứng dụng
        install(handler);
        await body();
      },
      (Object error, StackTrace stack) {
        unawaited(
          handler.handle(
            error,
            stack,
            source: 'global',
          ),
        );
      },
    );
  }
}
