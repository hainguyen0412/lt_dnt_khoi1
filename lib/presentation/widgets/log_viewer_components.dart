import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/error_handling/log_entry.dart';
import '../../core/errors/app_exception.dart';
import '../utils/severity_extension.dart';

/// Thanh lọc các bản ghi nhật ký theo mức độ nghiêm trọng [Severity].
class LogFilterChipsBar extends StatelessWidget {
  /// Mức độ nghiêm trọng hiện đang chọn (null nếu là 'Tất cả').
  final Severity? selectedSeverity;

  /// Callback khi người dùng chọn lọc mức độ mới.
  final ValueChanged<Severity?> onSelected;

  /// Khởi tạo [LogFilterChipsBar].
  const LogFilterChipsBar({
    super.key,
    required this.selectedSeverity,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: const Text('Tất cả'),
              selected: selectedSeverity == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...Severity.values.map((sev) {
            final isSelected = selectedSeverity == sev;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                avatar: Icon(
                  sev.icon,
                  size: 16,
                  color: sev.color,
                ),
                label: Text(sev.name.toUpperCase()),
                selected: isSelected,
                onSelected: (_) => onSelected(isSelected ? null : sev),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Thẻ hiển thị một dòng nhật ký lỗi kèm khả năng chạm để mở rộng chi tiết.
class LogEntryTile extends StatelessWidget {
  /// Bản ghi nhật ký cần hiển thị.
  final LogEntry entry;

  /// Callback khi người dùng nhấn nút sao chép nội dung log.
  final VoidCallback onCopy;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Khởi tạo [LogEntryTile].
  const LogEntryTile({
    super.key,
    required this.entry,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.severity.color;
    final icon = entry.severity.icon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(26),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          entry.errorType,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildSubtitle(theme),
        children: [
          _buildExpandedDetails(theme),
        ],
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(
          entry.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            LogSeverityBadge(severity: entry.severity),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_dateFormat.format(entry.timestamp)} • ${entry.source ?? "global"}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedDetails(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Mã lỗi (Code)', entry.code),
          _buildInfoRow(
            'Nguồn (Source)',
            entry.source ?? 'Không xác định',
          ),
          if (entry.originalError != null)
            _buildInfoRow('Lỗi gốc', entry.originalError!),
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Stack Trace:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  entry.stackTrace!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Sao chép chi tiết'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Huy hiệu hiển thị mức độ lỗi [Severity] kết hợp cả icon, chữ và màu sắc (A11y).
class LogSeverityBadge extends StatelessWidget {
  /// Mức độ lỗi cần hiển thị.
  final Severity severity;

  /// Khởi tạo [LogSeverityBadge].
  const LogSeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = severity.color;
    final icon = severity.icon;
    final text = severity.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Giao diện hiển thị trạng thái danh sách nhật ký rỗng.
class LogEmptyView extends StatelessWidget {
  /// Khởi tạo [LogEmptyView].
  const LogEmptyView({super.key});

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
              Icons.verified_outlined,
              size: 68,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'Hệ thống hoạt động ổn định',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa có lỗi nào được ghi lại.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
