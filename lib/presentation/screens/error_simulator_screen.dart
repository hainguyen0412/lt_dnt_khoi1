import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/simulation/failure_mode.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/entities/transaction_type.dart';
import '../state/transaction_notifier.dart';
import '../widgets/simulator_action_cards.dart';
import 'log_viewer_screen.dart';

/// Màn hình điều khiển và giả lập lỗi (Error Simulator) phục vụ phản biện và kiểm thử (T-305).
///
/// **Lý do thiết kế Clean Architecture (R10, R11):**
/// - Cho phép thay đổi [FailureSimulator] trong bộ nhớ để kích hoạt các chế độ lỗi mạng, timeout, server.
/// - **Tuyệt đối không import tầng Data:** Điều khiển lỗi thông qua `FailureSimulator` (đặt tại `core/simulation`)
///   và `TransactionNotifier` thông qua Provider.
/// - Mỗi thao tác đều ánh xạ tới một yêu cầu kiến trúc của đồ án (Error Boundary, Global Hooks, Validation).
class ErrorSimulatorScreen extends StatefulWidget {
  /// Simulator tiêm từ ngoài (tùy chọn, phục vụ testing).
  final FailureSimulator? simulator;

  /// Notifier tiêm từ ngoài (tùy chọn, phục vụ testing).
  final TransactionNotifier? notifier;

  /// Callback kích hoạt lỗi async (tùy chọn, phục vụ testing cô lập).
  final VoidCallback? onTriggerAsyncError;

  /// Khởi tạo [ErrorSimulatorScreen].
  const ErrorSimulatorScreen({
    super.key,
    this.simulator,
    this.notifier,
    this.onTriggerAsyncError,
  });

  @override
  State<ErrorSimulatorScreen> createState() => _ErrorSimulatorScreenState();
}

class _ErrorSimulatorScreenState extends State<ErrorSimulatorScreen> {
  bool _isBuildErrorTriggered = false;
  bool _isReloading = false;

  TransactionNotifier _getNotifier(BuildContext context) {
    return widget.notifier ?? context.read<TransactionNotifier>();
  }

  Future<void> _handleReload(BuildContext context) async {
    setState(() => _isReloading = true);
    final notifier = _getNotifier(context);
    await notifier.load();
    if (mounted) {
      setState(() => _isReloading = false);
    }
  }

  void _handleTriggerAsyncError(BuildContext context) {
    if (widget.onTriggerAsyncError != null) {
      widget.onTriggerAsyncError!();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        throw StateError(
          'Lỗi bất đồng bộ ngoài widget tree (Global Error Hooks demo T-305)',
        );
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã kích hoạt lỗi async. Kiểm tra console hoặc Log Viewer để thấy bản ghi!',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleTriggerValidation(BuildContext context) async {
    final notifier = _getNotifier(context);
    final draft = TransactionDraft(
      type: TransactionType.expense,
      title: 'Demo lỗi số tiền âm',
      amount: const Money(-50000),
      category: Category.other,
      date: DateTime.now(),
    );
    await notifier.add(draft);
  }

  void _openLogViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LogViewerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final simulator = widget.simulator ?? context.watch<FailureSimulator>();
    final notifier = widget.notifier ?? context.watch<TransactionNotifier>();

    return ListenableBuilder(
      listenable: Listenable.merge([simulator, notifier]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Bảng Giả Lập Lỗi (Simulator)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_edu_outlined),
                tooltip: 'Xem nhật ký lỗi (Log Viewer)',
                onPressed: () => _openLogViewer(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ModeSelectorCard(
                currentMode: simulator.mode,
                onModeChanged: (newMode) => simulator.mode = newMode,
              ),
              const SizedBox(height: 12),
              ReloadListCard(
                onReload: () => _handleReload(context),
                state: notifier.listState,
                isLoading: _isReloading,
              ),
              const SizedBox(height: 12),
              BuildErrorCard(
                isTriggered: _isBuildErrorTriggered,
                onToggle: (val) => setState(() => _isBuildErrorTriggered = val),
              ),
              const SizedBox(height: 12),
              AsyncErrorCard(
                onTrigger: () => _handleTriggerAsyncError(context),
              ),
              const SizedBox(height: 12),
              ValidationErrorCard(
                onTrigger: () => _handleTriggerValidation(context),
                fieldError: notifier.fieldErrors['amount'],
              ),
            ],
          ),
        );
      },
    );
  }
}
