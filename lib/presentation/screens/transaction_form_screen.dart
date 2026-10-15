import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/entities/transaction_type.dart';
import '../state/transaction_notifier.dart';
import '../utils/money_formatter.dart';
import '../widgets/error_boundary.dart';

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TypeSelector(
                    selectedType: _selectedType,
                    onChanged: (newType) {
                      setState(() => _selectedType = newType);
                    },
                  ),
                  const SizedBox(height: 20),
                  _TitleField(
                    controller: _titleController,
                    errorText: notifier.fieldErrors['title'],
                    onChanged: (_) => notifier.clearFieldErrors('title'),
                  ),
                  const SizedBox(height: 16),
                  _AmountField(
                    controller: _amountController,
                    errorText: notifier.fieldErrors['amount'],
                    onChanged: (_) => notifier.clearFieldErrors('amount'),
                  ),
                  const SizedBox(height: 16),
                  _CategoryDropdown(
                    selectedCategory: _selectedCategory,
                    onChanged: (newCat) {
                      if (newCat != null) {
                        setState(() => _selectedCategory = newCat);
                        notifier.clearFieldErrors('category');
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _DatePickerTile(
                    selectedDate: _selectedDate,
                    errorText: notifier.fieldErrors['date'],
                    onDatePicked: (picked) {
                      setState(() => _selectedDate = picked);
                      notifier.clearFieldErrors('date');
                    },
                  ),
                  const SizedBox(height: 16),
                  _NoteField(controller: _noteController),
                  const SizedBox(height: 32),
                  _SaveButton(
                    isSubmitting: notifier.isSubmitting,
                    isEditing: _isEditing,
                    onPressed: () => _onSave(notifier),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSave(TransactionNotifier notifier) async {
    // Parse bằng int.tryParse, null thì truyền 0 để Domain bắt lỗi validation
    final parsedAmount = int.tryParse(_amountController.text.trim()) ?? 0;
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    bool success;
    if (_isEditing) {
      final updatedTx = widget.initialTransaction!.copyWith(
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa giao dịch "${widget.initialTransaction!.title}" không?',
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
      final success = await notifier.delete(widget.initialTransaction!.id);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }
}

// ================= CÁC WIDGET CON PHÂN RÃ =================

class _TypeSelector extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          icon: Icon(Icons.arrow_downward_rounded, color: Colors.red),
          label: Text('Chi tiêu (-)'),
        ),
        ButtonSegment(
          value: TransactionType.income,
          icon: Icon(Icons.arrow_upward_rounded, color: Colors.green),
          label: Text('Thu nhập (+)'),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _TitleField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Tiêu đề giao dịch *',
        hintText: 'Ví dụ: Ăn trưa, Tiền lương...',
        prefixIcon: const Icon(Icons.title_rounded),
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      onChanged: onChanged,
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _AmountField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: false,
      ),
      decoration: InputDecoration(
        labelText: 'Số tiền (VND) *',
        hintText: 'Nhập số tiền (ví dụ: 50000)',
        prefixIcon: const Icon(Icons.attach_money_rounded),
        suffixText: '₫',
        border: const OutlineInputBorder(),
        errorText: errorText,
        helperText: 'Cho phép nhập dấu "-" ở đầu để demo kiểm tra lỗi số âm',
      ),
      onChanged: onChanged,
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final Category selectedCategory;
  final ValueChanged<Category?> onChanged;

  const _CategoryDropdown({
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Category>(
      initialValue: selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Danh mục *',
        prefixIcon: Icon(Icons.category_rounded),
        border: OutlineInputBorder(),
      ),
      items: Category.values.map((cat) {
        return DropdownMenuItem(
          value: cat,
          child: Row(
            children: [
              Icon(_getCategoryIcon(cat), size: 20),
              const SizedBox(width: 8),
              Text(_getCategoryLabel(cat)),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  static IconData _getCategoryIcon(Category cat) {
    return switch (cat) {
      Category.food => Icons.restaurant_rounded,
      Category.transport => Icons.directions_car_rounded,
      Category.shopping => Icons.shopping_bag_rounded,
      Category.bills => Icons.receipt_long_rounded,
      Category.health => Icons.medical_services_rounded,
      Category.entertainment => Icons.sports_esports_rounded,
      Category.salary => Icons.payments_rounded,
      Category.other => Icons.category_rounded,
    };
  }

  static String _getCategoryLabel(Category cat) {
    return switch (cat) {
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

class _DatePickerTile extends StatelessWidget {
  final DateTime selectedDate;
  final String? errorText;
  final ValueChanged<DateTime> onDatePicked;

  const _DatePickerTile({
    required this.selectedDate,
    required this.errorText,
    required this.onDatePicked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(1990),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onDatePicked(picked);
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Ngày giao dịch *',
              prefixIcon: const Icon(Icons.calendar_today_rounded),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            child: Text(
              MoneyFormatter.formatDate(selectedDate),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4.0),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _NoteField extends StatelessWidget {
  final TextEditingController controller;

  const _NoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Ghi chú (tùy chọn)',
        hintText: 'Thêm thông tin chi tiết về giao dịch này...',
        prefixIcon: Icon(Icons.note_alt_outlined),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isSubmitting;
  final bool isEditing;
  final VoidCallback onPressed;

  const _SaveButton({
    required this.isSubmitting,
    required this.isEditing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSubmitting ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
      child: isSubmitting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              isEditing ? 'Cập nhật giao dịch' : 'Lưu giao dịch',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
