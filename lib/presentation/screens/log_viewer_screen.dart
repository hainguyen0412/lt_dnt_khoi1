import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/error_handling/error_handler.dart';
import '../../core/error_handling/error_logger.dart';
import '../../core/error_handling/log_entry.dart';
import '../../core/error_handling/user_facing_error.dart';
import '../../core/errors/app_exception.dart';
import '../widgets/error_view.dart';
import '../widgets/log_viewer_components.dart';

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

    final loadError = _loadError;
    if (loadError != null) {
      return ErrorView(
        error: loadError,
        onRetry: _loadLogs,
      );
    }

    final filteredLogs = _selectedSeverity == null
        ? _logs
        : _logs.where((l) => l.severity == _selectedSeverity).toList();

    return Column(
      children: [
        LogFilterChipsBar(
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
                      return LogEntryTile(
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
      return const LogEmptyView();
    }
    final selectedSeverity = _selectedSeverity;
    final sevName =
        selectedSeverity != null ? selectedSeverity.name.toUpperCase() : '';
    return Center(
      child: Text(
        'Không có bản ghi nào ở mức $sevName.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
