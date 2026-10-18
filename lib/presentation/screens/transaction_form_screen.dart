import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/entities/transaction_type.dart';
import '../state/transaction_notifier.dart';
import '../widgets/error_boundary.dart';
import '../widgets/transaction_form_fields.dart';

/// Màn hình biểu mẫu thêm mới hoặc chỉnh sửa giao dịch (T-303).
///
/// **Lý do thiết kế Clean Architecture (R5, R9):**
/// 1. **UI không tự validate nghiệp vụ:** Form không kiểm tra rỗng, âm hay ngày tương lai.
///    Toàn bộ dữ liệu được đóng gói gửi xuống Domain để `ValidatableMixin` và `TransactionRules`
///    kiểm tra.
/// 2. **Hiển thị lỗi từng trường trực quan:** Lỗi hiển thị dưới mỗi ô nhập được đọc trực tiếp từ
///    `notifier.fieldErrors[tên_trường]`, chứng minh rõ ràng quy tắc thuộc về Domain.
/// 3. **Chống bấm đúp (R8):** Khóa nút Lưu khi `notifier.isSubmitting == true`.
class TransactionFormScreen extends StatefulWidget {
  /// Giao dịch ban đầu nếu đang ở chế độ chỉnh sửa (null nếu thêm mới).
  final Transaction? initialTransaction;

  /// Khởi tạo [TransactionFormScreen].
  const TransactionFormScreen({
    super.key,
    this.initialTransaction,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  late TransactionType _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late Category _selectedCategory;
  late DateTime _selectedDate;

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTransaction;

    _selectedType = initial?.type ?? TransactionType.expense;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _amountController = TextEditingController(
      text: initial != null ? initial.amount.amount.toString() : '',
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _selectedCategory = initial?.category ?? Category.food;
    _selectedDate = initial?.date ?? DateTime.now();

    // Xóa sạch lỗi cũ từ các phiên thao tác trước đó
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifier = context.read<TransactionNotifier>();
        notifier.clearFieldErrors();
        notifier.clearActionError();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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
            action: actionError.canRetry
                ? SnackBarAction(
                    label: 'Thử lại',
                    textColor: Colors.white,
                    onPressed: () => notifier.retryLast(),
                  )
                : null,
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
            title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Xóa giao dịch',
                  onPressed:
                      notifier.isSubmitting ? null : () => _onDelete(notifier),
                ),
            ],
          ),
          body: ErrorBoundary(
            errorSource: notifier.boundaryError,
            onRetry: () => notifier.retryLast(),
            onDismiss: () => notifier.clearBoundaryError(),
            child: _buildFormContent(notifier),
          ),
        );
      },
    );
  }

  Widget _buildFormContent(TransactionNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TypeSelectorField(
            selectedType: _selectedType,
            onChanged: (newType) {
              setState(() => _selectedType = newType);
            },
          ),
          const SizedBox(height: 20),
          TitleInputField(
            controller: _titleController,
            errorText: notifier.fieldErrors['title'],
            onChanged: (_) => notifier.clearFieldErrors('title'),
          ),
          const SizedBox(height: 16),
          AmountInputField(
            controller: _amountController,
            errorText: notifier.fieldErrors['amount'],
            onChanged: (_) => notifier.clearFieldErrors('amount'),
          ),
          const SizedBox(height: 16),
          CategoryDropdownField(
            selectedCategory: _selectedCategory,
            onChanged: (newCat) {
              if (newCat != null) {
                setState(() => _selectedCategory = newCat);
                notifier.clearFieldErrors('category');
              }
            },
          ),
          const SizedBox(height: 16),
          DatePickerField(
            selectedDate: _selectedDate,
            errorText: notifier.fieldErrors['date'],
            onDatePicked: (picked) {
              setState(() => _selectedDate = picked);
              notifier.clearFieldErrors('date');
            },
          ),
          const SizedBox(height: 16),
          NoteInputField(controller: _noteController),
          const SizedBox(height: 32),
          SaveSubmitButton(
            isSubmitting: notifier.isSubmitting,
            isEditing: _isEditing,
            onPressed: () => _onSave(notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave(TransactionNotifier notifier) async {
    // Parse bằng int.tryParse, null thì truyền 0 để Domain bắt lỗi validation
    final parsedAmount = int.tryParse(_amountController.text.trim()) ?? 0;
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    bool success;
    if (_isEditing) {
      final initial = widget.initialTransaction;
      if (initial == null) return;

      final updatedTx = initial.copyWith(
        type: _selectedType,
        title: _titleController.text.trim(),
        amount: Money(parsedAmount),
        category: _selectedCategory,
        date: _selectedDate,
        note: note,
        updatedAt: DateTime.now(),
      );
      success = await notifier.update(updatedTx);
    } else {
      final draft = TransactionDraft(
        type: _selectedType,
        title: _titleController.text.trim(),
        amount: Money(parsedAmount),
        category: _selectedCategory,
        date: _selectedDate,
        note: note,
      );
      success = await notifier.add(draft);
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onDelete(TransactionNotifier notifier) async {
    final initial = widget.initialTransaction;
    if (initial == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa giao dịch "${initial.title}" không?',
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

    if (confirmed == true) {
      final success = await notifier.delete(initial.id);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }
}
