import 'package:flutter/material.dart';

import '../../core/error_handling/user_facing_error.dart';
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
            _buildChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildChips() {
    return Wrap(
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
    if (isLoading) return _buildLoading();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return switch (state) {
      TransactionListInitial() => const Text('Chưa tải dữ liệu.'),
      TransactionListLoading() => _buildLoading(),
      TransactionListLoaded(:final items) => _buildLoaded(items.length, theme),
      TransactionListEmpty() => _buildEmpty(colorScheme),
      TransactionListError(:final error) =>
        _buildError(error, theme, colorScheme),
    };
  }

  Widget _buildLoading() {
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

  Widget _buildLoaded(int count, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha(77)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tải thành công: $count giao dịch.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.green.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Container(
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
    );
  }

  Widget _buildError(
    UserFacingError error,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(77),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withAlpha(77)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
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
    );
  }
}
