import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';

/// Các tiện ích hiển thị giao diện cho [Severity].
extension SeverityPresentationX on Severity {
  /// Biểu tượng Material Icon trực quan theo mức độ nghiêm trọng của sự cố.
  IconData get icon {
    return switch (this) {
      Severity.info => Icons.info_outline_rounded,
      Severity.warning => Icons.warning_amber_rounded,
      Severity.error => Icons.error_outline_rounded,
      Severity.critical => Icons.gpp_bad_rounded,
    };
  }

  /// Màu sắc đặc trưng đại diện cho từng cấp độ sự cố (A11y: kết hợp cùng icon và chữ).
  Color get color {
    return switch (this) {
      Severity.info => Colors.blue.shade700,
      Severity.warning => Colors.orange.shade800,
      Severity.error => Colors.red.shade700,
      Severity.critical => Colors.purple.shade900,
    };
  }

  /// Nhãn văn bản viết tắt thể hiện mức độ lỗi (A11y: hỗ trợ người khiếm thị màu).
  String get label {
    return switch (this) {
      Severity.info => 'INFO',
      Severity.warning => 'WARN',
      Severity.error => 'ERROR',
      Severity.critical => 'CRITICAL',
    };
  }
}
