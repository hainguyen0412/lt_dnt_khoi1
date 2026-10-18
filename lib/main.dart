import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/error_handling/console_logger.dart';
import 'core/error_handling/error_handler.dart';
import 'core/error_handling/error_logger.dart';
import 'core/error_handling/error_message_mapper.dart';
import 'core/error_handling/error_widget_setup.dart';
import 'core/error_handling/file_logger.dart';
import 'core/error_handling/global_error_hooks.dart';

void main() {
  // 1. Khởi tạo sớm hạ tầng ErrorHandler để kích hoạt lưới an toàn ngay từ trước khi chạy app
  final FileLogger fileLogger = FileLogger();
  final List<ErrorLogger> loggers = <ErrorLogger>[
    const ConsoleLogger(),
    fileLogger,
  ];
  final ErrorHandler errorHandler = ErrorHandler(
    loggers: loggers,
    messageMapper: const ErrorMessageMapper(),
  );

  // 2. Chạy ứng dụng an toàn bên trong Zone được bảo vệ bởi GlobalErrorHooks (R10)
  // LƯU Ý KIẾN TRÚC: `WidgetsFlutterBinding.ensureInitialized()`, `buildDependencies()`
  // và `runApp()` đều nằm trong CÙNG MỘT Zone để loại trừ hoàn toàn hiện tượng Zone Mismatch.
  GlobalErrorHooks.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Cài đặt ErrorWidget.builder thay thế màn hình đỏ/xám khi xảy ra lỗi render lúc build (T-304, R10)
    installErrorWidgetBuilder();

    // 3. Lắp ráp toàn bộ cây phụ thuộc tại Composition Root (R5, R6)
    final AppDependencies dependencies = await buildDependencies(
      errorHandlerOverride: errorHandler,
      loggersOverride: loggers,
      fileLoggerOverride: fileLogger,
    );

    // 4. Khởi chạy ứng dụng với MultiProvider nhận dependencies
    runApp(ExpenseTrackerApp(dependencies: dependencies));
  }, errorHandler);
}
