import 'package:flutter/material.dart';

/// Widget hiển thị trạng thái danh sách giao dịch hoàn toàn rỗng.
class EmptyView extends StatelessWidget {
  /// Callback khi người dùng nhấn nút thêm giao dịch đầu tiên.
  final VoidCallback? onAddPressed;

  /// Khởi tạo [EmptyView] với callback [onAddPressed] tùy chọn.
  const EmptyView({
    super.key,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: colorScheme.outline.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có giao dịch nào',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy bắt đầu theo dõi chi tiêu bằng cách ghi lại khoản thu - chi đầu tiên của bạn.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddPressed != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm giao dịch'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
