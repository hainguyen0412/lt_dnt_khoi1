import 'package:flutter/material.dart';

import '../../core/error_handling/user_facing_error.dart';
import '../../core/errors/app_exception.dart';

/// Widget hiển thị thông báo lỗi thân thiện cho người dùng (R10).
///
/// **Lý do thiết kế:**
/// - Đảm bảo Information Hiding: Chỉ nhận [UserFacingError] và không bao giờ để lộ stacktrace.
/// - Nút "Thử lại": Chỉ xuất hiện khi [error.canRetry] là `true` và có [onRetry].
/// - Named constructor [ErrorView.compact]: Phục vụ `ErrorWidget.builder` ở T-304 để thay thế
///   các widget render lỗi cục bộ mà không phá vỡ bố cục màn hình.
class ErrorView extends StatelessWidget {
  /// Đối tượng lỗi an toàn đã qua xử lý.
  final UserFacingError error;

  /// Callback thực thi khi người dùng bấm "Thử lại".
  final VoidCallback? onRetry;

  /// Callback thực thi khi người dùng bấm nút bỏ qua / đóng giao diện lỗi.
  final VoidCallback? onDismiss;

  /// Nhãn hiển thị cho nút bỏ qua (mặc định là 'Bỏ qua').
  final String? dismissLabel;

  /// Cho biết chế độ hiển thị có phải là thu gọn (compact) hay không.
  final bool isCompact;

  /// Khởi tạo [ErrorView] mặc định cho giao diện toàn màn hình.
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.dismissLabel,
    this.isCompact = false,
  });

  /// Khởi tạo [ErrorView] dạng thu gọn (phục vụ ErrorWidget.builder ở T-304).
  const ErrorView.compact({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.dismissLabel,
  }) : isCompact = true;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompact(context);
    }
    return _buildFullScreen(context);
  }

  Widget _buildFullScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, color) = _getSeverityPresentation(colorScheme);

    final hasRetry = error.canRetry && onRetry != null;
    final hasDismiss = onDismiss != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              'Đã xảy ra sự cố',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasRetry || hasDismiss) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasDismiss)
                    OutlinedButton(
                      onPressed: onDismiss,
                      child: Text(dismissLabel ?? 'Bỏ qua'),
                    ),
                  if (hasDismiss && hasRetry) const SizedBox(width: 12),
                  if (hasRetry)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, color) = _getSeverityPresentation(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(102),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (error.canRetry && onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: onRetry,
              tooltip: 'Thử lại',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color) _getSeverityPresentation(ColorScheme colorScheme) {
    return switch (error.severity) {
      Severity.info => (Icons.info_outline_rounded, colorScheme.primary),
      Severity.warning => (Icons.warning_amber_rounded, Colors.orange),
      Severity.error => (Icons.error_outline_rounded, colorScheme.error),
      Severity.critical => (Icons.gpp_bad_rounded, Colors.red.shade800),
    };
  }
}
