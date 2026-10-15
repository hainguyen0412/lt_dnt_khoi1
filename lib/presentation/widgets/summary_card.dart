import 'package:flutter/material.dart';

import '../../domain/entities/money.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/entities/transaction_type.dart';
import '../utils/money_formatter.dart';

/// Thẻ Card hiển thị tổng quan tình hình tài chính (Số dư, Tổng thu, Tổng chi).
class SummaryCard extends StatelessWidget {
  /// Thống kê tài chính cần hiển thị.
  final TransactionSummary summary;

  /// Khởi tạo [SummaryCard].
  const SummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final balance = summary.balance;
    final isNegative = balance.amount < 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số dư hiện tại',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isNegative
                  ? '- ${MoneyFormatter.formatVnd(balance.amount.abs())}'
                  : MoneyFormatter.formatVnd(balance.amount),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isNegative ? colorScheme.error : colorScheme.primary,
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Tổng thu',
                    amount: summary.totalIncome,
                    type: TransactionType.income,
                    color: Colors.green.shade700,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Tổng chi',
                    amount: summary.totalExpense,
                    type: TransactionType.expense,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final Money amount;
  final TransactionType type;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.amount,
    required this.type,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = type == TransactionType.income;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncome
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            MoneyFormatter.formatWithSign(amount, type),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
