import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/transaction.dart';
import '../state/transaction_notifier.dart';
import '../state/transaction_state.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_boundary.dart';
import '../widgets/error_view.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'error_simulator_screen.dart';
import 'log_viewer_screen.dart';
import 'transaction_form_screen.dart';

/// Màn hình chính hiển thị danh sách các giao dịch thu - chi và tổng kết tài chính (T-302).
///
/// **Lý do thiết kế:**
/// - Render giao diện phụ thuộc chặt chẽ vào [TransactionListState] thông qua `switch expression`.
/// - Hỗ trợ kéo để làm mới (`RefreshIndicator`) ở cả trạng thái có dữ liệu và danh sách rỗng.
/// - Lắng nghe lỗi thao tác ngầm ([TransactionNotifier.actionError]) để hiển thị SnackBar mà không làm mất danh sách.
class TransactionListScreen extends StatefulWidget {
  /// Khởi tạo [TransactionListScreen].
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionNotifier>().load();
      }
    });
  }

  void _listenToActionError(
    BuildContext context,
    TransactionNotifier notifier,
  ) {
    final actionError = notifier.actionError;
    if (actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(actionError.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearActionError();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionNotifier>(
      builder: (context, notifier, child) {
        _listenToActionError(context, notifier);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sổ Chi Tiêu'),
            actions: [
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: 'Giả lập lỗi',
                onPressed: () => _openErrorSimulator(context),
              ),
              IconButton(
                icon: const Icon(Icons.history_edu_outlined),
                tooltip: 'Nhật ký lỗi',
                onPressed: () => _openLogViewer(context),
              ),
            ],
          ),
          body: ErrorBoundary(
            errorSource: notifier.boundaryError,
            onRetry: () => notifier.retryLast(),
            onDismiss: () => notifier.clearBoundaryError(),
            child: _buildBody(context, notifier),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToAddScreen(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm giao dịch'),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TransactionNotifier notifier) {
    return switch (notifier.listState) {
      TransactionListInitial() || TransactionListLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      TransactionListEmpty() => RefreshIndicator(
          onRefresh: () => notifier.load(),
          child: ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: EmptyView(
                  onAddPressed: () => _navigateToAddScreen(context),
                ),
              ),
            ],
          ),
        ),
      TransactionListError(error: final err) => ErrorView(
          error: err,
          onRetry: () => notifier.load(),
        ),
      TransactionListLoaded(items: final items, summary: final summary) =>
        RefreshIndicator(
          onRefresh: () => notifier.load(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SummaryCard(summary: summary),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 80.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return TransactionTile(
                        transaction: item,
                        onTap: () => _navigateToEditScreen(context, item),
                        onDelete: () => notifier.delete(item.id),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          ),
        ),
    };
  }

  void _navigateToAddScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TransactionFormScreen(),
      ),
    );
  }

  void _navigateToEditScreen(BuildContext context, Transaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          initialTransaction: transaction,
        ),
      ),
    );
  }

  void _openErrorSimulator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ErrorSimulatorScreen(),
      ),
    );
  }

  void _openLogViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LogViewerScreen(),
      ),
    );
  }
}
