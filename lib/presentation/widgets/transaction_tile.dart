import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';
import '../utils/category_extension.dart';
import '../utils/money_formatter.dart';

/// Thẻ hiển thị một giao dịch thu - chi trong danh sách kèm thao tác vuốt để xóa.
class TransactionTile extends StatelessWidget {
  /// Thực thể giao dịch cần hiển thị.
  final Transaction transaction;

  /// Callback khi nhấn vào tile để xem hoặc chỉnh sửa.
  final VoidCallback? onTap;

  /// Callback khi người dùng xác nhận xóa giao dịch bằng thao tác vuốt.
  final VoidCallback? onDelete;

  /// Khởi tạo [TransactionTile].
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: const _DismissibleBackground(),
      confirmDismiss: (direction) => _showConfirmDeleteDialog(context),
      onDismissed: (direction) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        leading: _CategoryIconBadge(
          category: transaction.category,
          type: transaction.type,
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_getCategoryLabel(transaction.category)} • ${MoneyFormatter.formatDate(transaction.date)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: _AmountTrailing(
          amount: transaction.amount,
          type: transaction.type,
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa giao dịch "${transaction.title}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  static String _getCategoryLabel(Category category) {
    return switch (category) {
      Category.food => 'Ăn uống',
      Category.transport => 'Di chuyển',
      Category.shopping => 'Mua sắm',
      Category.bills => 'Hóa đơn',
      Category.health => 'Sức khỏe',
      Category.entertainment => 'Giải trí',
      Category.salary => 'Lương thưởng',
      Category.other => 'Khác',
    };
  }
}

class _DismissibleBackground extends StatelessWidget {
  const _DismissibleBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Icon(
        Icons.delete_outline_rounded,
        color: colorScheme.onError,
        size: 28,
      ),
    );
  }
}

class _CategoryIconBadge extends StatelessWidget {
  final Category category;
  final TransactionType type;

  const _CategoryIconBadge({
    required this.category,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == TransactionType.income;
    final color = isIncome ? Colors.green.shade700 : Colors.red.shade700;
    final backgroundColor =
        isIncome ? Colors.green.withAlpha(31) : Colors.red.withAlpha(31);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        category.icon,
        color: color,
        size: 22,
      ),
    );
  }
}

class _AmountTrailing extends StatelessWidget {
  final Money amount;
  final TransactionType type;

  const _AmountTrailing({
    required this.amount,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == TransactionType.income;
    final color = isIncome ? Colors.green.shade700 : Colors.red.shade700;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          MoneyFormatter.formatWithSign(amount, type),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }
}
