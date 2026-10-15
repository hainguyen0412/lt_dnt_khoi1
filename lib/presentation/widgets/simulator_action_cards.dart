import 'package:flutter/material.dart';

export 'simulator_mode_cards.dart';

/// Card demo lỗi render lúc build() để kiểm chứng [ErrorWidget.builder] (T-305, R10).
class BuildErrorCard extends StatelessWidget {
  /// Cờ bật/tắt widget con gây lỗi.
  final bool isTriggered;

  /// Callback chuyển đổi cờ.
  final ValueChanged<bool> onToggle;

  /// Khởi tạo [BuildErrorCard].
  const BuildErrorCard({
    super.key,
    required this.isTriggered,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isTriggered ? Colors.green : colorScheme.error,
              ),
              onPressed: () => onToggle(!isTriggered),
              icon: Icon(isTriggered
                  ? Icons.check_circle_outline_rounded
                  : Icons.bug_report_rounded),
              label: Text(
                isTriggered
                    ? 'Khôi phục build bình thường'
                    : 'Kích hoạt lỗi render trong build',
              ),
            ),
            const SizedBox(height: 8),
            _buildPreview(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.layers_clear_rounded, color: colorScheme.error),
            const SizedBox(width: 8),
            Text(
              '3. Gây lỗi trong phương thức build()',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Minh họa ErrorWidget.builder và Error Boundary tầng render (R10).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme colorScheme) {
    if (isTriggered) return const _CrashingSampleWidget();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Widget con đang render bình thường.'),
    );
  }
}

/// Widget con ném lỗi cố ý trong phương thức build().
class _CrashingSampleWidget extends StatelessWidget {
  const _CrashingSampleWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('Lỗi giả lập trong phương thức build() để demo T-304');
  }
}

/// Card demo lỗi async ngoài widget tree để kiểm chứng [GlobalErrorHooks] (T-305, R10, R11).
class AsyncErrorCard extends StatelessWidget {
  /// Callback gây lỗi async.
  final VoidCallback onTrigger;

  /// Khởi tạo [AsyncErrorCard].
  const AsyncErrorCard({
    super.key,
    required this.onTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text(
                  '4. Gây lỗi async ngoài cây widget',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Minh họa 3-tier Global Safety Net (PlatformDispatcher.onError / runZonedGuarded) và tự động ghi log (R10, R11).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTrigger,
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text('Kích hoạt lỗi unhandled async'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card demo lỗi thẩm định nghiệp vụ Domain Validation (T-305, R5, R9).
class ValidationErrorCard extends StatelessWidget {
  /// Callback kích hoạt gửi giao dịch không hợp lệ.
  final VoidCallback onTrigger;

  /// Thông điệp lỗi đọc từ fieldErrors của Notifier.
  final String? fieldError;

  /// Khởi tạo [ValidationErrorCard].
  const ValidationErrorCard({
    super.key,
    required this.onTrigger,
    this.fieldError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule_rounded, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  '5. Gây lỗi Domain Validation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Gửi giao dịch có số tiền âm (-50.000 ₫) để chứng minh Domain chặn lỗi và ánh xạ vào fieldErrors (R5, R9).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTrigger,
              icon: const Icon(Icons.do_not_disturb_on_total_silence_rounded),
              label: const Text('Gửi giao dịch số tiền âm'),
            ),
            if (fieldError != null) ...[
              const SizedBox(height: 8),
              _buildErrorBox(colorScheme, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBox(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(77),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.error.withAlpha(77)),
      ),
      child: Text(
        'fieldErrors["amount"]: $fieldError',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
