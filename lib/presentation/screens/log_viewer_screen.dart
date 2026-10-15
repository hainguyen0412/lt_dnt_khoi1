import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/error_handling/error_handler.dart';
import '../../core/error_handling/error_logger.dart';
import '../../core/error_handling/log_entry.dart';
import '../../core/error_handling/user_facing_error.dart';
import '../../core/errors/app_exception.dart';
import '../widgets/error_view.dart';

/// Màn hình tra cứu và quản lý nhật ký lỗi hệ thống (Log Viewer - T-306).
///
/// **Lý do thiết kế Clean Architecture (R11):**
/// - Đọc log qua abstraction [ErrorLogger] (instance FileLogger) được inject từ Provider,
///   tuyệt đối không import tầng `data`.
/// - Thể hiện tính toàn vẹn của Centralized Error Pipeline: Cho phép thanh tra, lọc và sao chép
///   các ngoại lệ đã được lưu trữ bền vững.
/// - Nếu thao tác đọc file log gặp sự cố, lỗi được chuẩn hóa qua [ErrorHandler] và hiển thị
///   bằng [ErrorView].
class LogViewerScreen extends StatefulWidget {
  /// Bộ ghi nhật ký lỗi (cho phép inject từ bên ngoài để phục vụ test).
  final ErrorLogger? logger;

  /// Bộ xử lý ngoại lệ tập trung (cho phép inject để phục vụ test).
  final ErrorHandler? errorHandler;

  /// Khởi tạo [LogViewerScreen].
  const LogViewerScreen({
    super.key,
    this.logger,
    this.errorHandler,
  });

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  bool _isLoading = true;
  List<LogEntry> _logs = [];
  Severity? _selectedSeverity;
  UserFacingError? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLogs();
      }
    });
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final logger = widget.logger ?? context.read<ErrorLogger>();
      final entries = await logger.readAll();
      if (!mounted) return;
      setState(() {
        _logs = entries;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      final errorHandler = widget.errorHandler ?? context.read<ErrorHandler>();
      final userError = await errorHandler.handle(
        error,
        stackTrace,
        source: 'LogViewer',
      );
      if (!mounted) return;
      setState(() {
        _loadError = userError;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmClearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa nhật ký'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử lỗi đã lưu không? Hành động này không thể hoàn tác.',
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
            child: const Text('Xóa toàn bộ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final logger = widget.logger ?? context.read<ErrorLogger>();
        await logger.clear();
        if (!mounted) return;
        setState(() {
          _logs = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa toàn bộ nhật ký lỗi.')),
        );
      } catch (error, stackTrace) {
        if (!mounted) return;
        final errorHandler =
            widget.errorHandler ?? context.read<ErrorHandler>();
        final userError = await errorHandler.handle(
          error,
          stackTrace,
          source: 'LogViewer',
        );
        if (!mounted) return;
        setState(() {
          _loadError = userError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyLogEntry(LogEntry entry) async {
    final buffer = StringBuffer()
      ..writeln('[${entry.severity.name.toUpperCase()}] ${entry.errorType}')
      ..writeln('Mã lỗi: ${entry.code}')
      ..writeln('Thời gian: ${entry.timestamp.toIso8601String()}')
      ..writeln('Nguồn phát sinh: ${entry.source ?? "Không xác định"}')
      ..writeln('Thông điệp: ${entry.message}');

    if (entry.originalError != null) {
      buffer.writeln('Lỗi gốc: ${entry.originalError}');
    }
    if (entry.stackTrace != null) {
      buffer.writeln('Stack Trace:\n${entry.stackTrace}');
    }

    try {
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
    } catch (_) {
      // Bỏ qua lỗi platform channel nếu chạy ở môi trường test không có clipboard service
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép nội dung log vào clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật Ký Lỗi (Log Viewer)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Xóa toàn bộ log',
            onPressed: _logs.isEmpty || _isLoading ? null : _confirmClearLogs,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return ErrorView(
        error: _loadError!,
        onRetry: _loadLogs,
      );
    }

    final filteredLogs = _selectedSeverity == null
        ? _logs
        : _logs.where((l) => l.severity == _selectedSeverity).toList();

    return Column(
      children: [
        _SeverityFilterBar(
          selectedSeverity: _selectedSeverity,
          onSelected: (sev) {
            setState(() => _selectedSeverity = sev);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredLogs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final entry = filteredLogs[index];
                      return _LogEntryTile(
                        entry: entry,
                        onCopy: () => _copyLogEntry(entry),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_logs.isEmpty) {
      return const _EmptyLogView();
    }
    return Center(
      child: Text(
        'Không có bản ghi nào ở mức ${_selectedSeverity!.name.toUpperCase()}.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ================= CÁC WIDGET CON PHÂN RÃ =================

class _SeverityFilterBar extends StatelessWidget {
  final Severity? selectedSeverity;
  final ValueChanged<Severity?> onSelected;

  const _SeverityFilterBar({
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
          FilterChip(
            label: const Text('Tất cả'),
            selected: selectedSeverity == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...Severity.values.map((sev) {
            final isSelected = selectedSeverity == sev;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                avatar: Icon(
                  _getSeverityIcon(sev),
                  size: 16,
                  color: _getSeverityColor(sev),
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

  static IconData _getSeverityIcon(Severity severity) {
    return switch (severity) {
      Severity.info => Icons.info_outline_rounded,
      Severity.warning => Icons.warning_amber_rounded,
      Severity.error => Icons.error_outline_rounded,
      Severity.critical => Icons.gpp_bad_rounded,
    };
  }

  static Color _getSeverityColor(Severity severity) {
    return switch (severity) {
      Severity.info => Colors.blue.shade700,
      Severity.warning => Colors.orange.shade800,
      Severity.error => Colors.red.shade700,
      Severity.critical => Colors.purple.shade900,
    };
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  final VoidCallback onCopy;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  const _LogEntryTile({
    required this.entry,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getSeverityColor(entry.severity);
    final icon = _getSeverityIcon(entry.severity);

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
        subtitle: Column(
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
                _SeverityBadge(severity: entry.severity),
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
        ),
        children: [
          Padding(
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

  static IconData _getSeverityIcon(Severity severity) {
    return switch (severity) {
      Severity.info => Icons.info_outline_rounded,
      Severity.warning => Icons.warning_amber_rounded,
      Severity.error => Icons.error_outline_rounded,
      Severity.critical => Icons.gpp_bad_rounded,
    };
  }

  static Color _getSeverityColor(Severity severity) {
    return switch (severity) {
      Severity.info => Colors.blue.shade700,
      Severity.warning => Colors.orange.shade800,
      Severity.error => Colors.red.shade700,
      Severity.critical => Colors.purple.shade900,
    };
  }
}

class _SeverityBadge extends StatelessWidget {
  final Severity severity;

  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (severity) {
      Severity.info => (Colors.blue.shade700, Icons.info_outline, 'INFO'),
      Severity.warning => (Colors.orange.shade800, Icons.warning_amber, 'WARN'),
      Severity.error => (Colors.red.shade700, Icons.error_outline, 'ERROR'),
      Severity.critical => (Colors.purple.shade900, Icons.gpp_bad, 'CRITICAL'),
    };

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

class _EmptyLogView extends StatelessWidget {
  const _EmptyLogView();

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
