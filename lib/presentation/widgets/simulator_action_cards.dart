import 'package:flutter/material.dart';

import '../../core/simulation/failure_mode.dart';
import '../state/transaction_state.dart';

/// Card lựa chọn chế độ giả lập lỗi [FailureMode] (T-305).
class ModeSelectorCard extends StatelessWidget {
  /// Chế độ lỗi hiện tại.
  final FailureMode currentMode;

  /// Callback khi người dùng chọn chế độ mới.
  final ValueChanged<FailureMode> onModeChanged;

  /// Khởi tạo [ModeSelectorCard].
  const ModeSelectorCard({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
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
                Icon(Icons.tune_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '1. Chế độ giả lập lỗi mạng / máy chủ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Có hiệu lực ngay lập tức lên FakeRemoteDataSource.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FailureMode.values.map((mode) {
                final isSelected = mode == currentMode;
                return ChoiceChip(
                  label: Text(_getModeLabel(mode)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      onModeChanged(mode);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getModeLabel(FailureMode mode) {
    return switch (mode) {
      FailureMode.none => 'Bình thường (None)',
      FailureMode.network => 'Mất mạng (Socket)',
      FailureMode.timeout => 'Quá hạn (Timeout)',
      FailureMode.server500 => 'Lỗi máy chủ (500)',
      FailureMode.badJson => 'JSON hỏng (Parse)',
      FailureMode.random => 'Ngẫu nhiên (Random)',
    };
  }
}

/// Card kiểm thử tải lại danh sách giao dịch qua Notifier (T-305).
class ReloadListCard extends StatelessWidget {
  /// Callback kích hoạt tải lại danh sách.
  final VoidCallback onReload;

  /// Trạng thái danh sách hiện tại của Notifier.
  final TransactionListState state;

  /// Cho biết thao tác đang được thực thi hay không.
  final bool isLoading;

  /// Khởi tạo [ReloadListCard].
  const ReloadListCard({
    super.key,
    required this.onReload,
    required this.state,
    required this.isLoading,
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
                Icon(Icons.sync_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '2. Kiểm thử tải danh sách',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Minh họa xử lý ngoại lệ I/O, chuyển đổi UserFacingError và fallback offline cache.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isLoading ? null : onReload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại danh sách (load)'),
            ),
            const SizedBox(height: 12),
            _buildStatusBox(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBox(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Đang tải danh sách...'),
        ],
      );
    }

    return switch (state) {
      TransactionListInitial() => const Text('Chưa tải dữ liệu.'),
      TransactionListLoading() => const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Đang tải danh sách...'),
          ],
        ),
      TransactionListLoaded(:final items) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withAlpha(77)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tải thành công: ${items.length} giao dịch.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      TransactionListEmpty() => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(51),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20),
              SizedBox(width: 8),
              Text('Danh sách rỗng (0 giao dịch).'),
            ],
          ),
        ),
      TransactionListError(:final error) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withAlpha(77),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.error.withAlpha(77)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lỗi hiển thị: ${error.message} (canRetry: ${error.canRetry})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
    };
  }
}

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
            if (isTriggered)
              const _CrashingSampleWidget()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(77),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Widget con đang render bình thường.'),
              ),
          ],
        ),
      ),
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
              Container(
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
