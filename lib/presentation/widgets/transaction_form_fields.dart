import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/transaction_type.dart';
import '../utils/category_extension.dart';
import '../utils/money_formatter.dart';

export 'save_submit_button.dart';

/// Ô chọn loại giao dịch: Thu nhập (+) hoặc Chi tiêu (-).
class TypeSelectorField extends StatelessWidget {
  /// Loại giao dịch đang chọn.
  final TransactionType selectedType;

  /// Callback khi người dùng thay đổi loại giao dịch.
  final ValueChanged<TransactionType> onChanged;

  /// Khởi tạo [TypeSelectorField].
  const TypeSelectorField({
    super.key,
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

/// Ô nhập tiêu đề giao dịch.
class TitleInputField extends StatelessWidget {
  /// Controller quản lý chuỗi tiêu đề.
  final TextEditingController controller;

  /// Thông báo lỗi từ Domain Validation (nếu có).
  final String? errorText;

  /// Callback kích hoạt khi người dùng gõ sửa lại ô nhập.
  final ValueChanged<String> onChanged;

  /// Khởi tạo [TitleInputField].
  const TitleInputField({
    super.key,
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

/// Ô nhập số tiền (VND).
class AmountInputField extends StatelessWidget {
  /// Controller quản lý chuỗi số tiền.
  final TextEditingController controller;

  /// Thông báo lỗi từ Domain Validation (nếu có).
  final String? errorText;

  /// Callback kích hoạt khi người dùng gõ sửa lại ô nhập.
  final ValueChanged<String> onChanged;

  /// Khởi tạo [AmountInputField].
  const AmountInputField({
    super.key,
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

/// Menu thả xuống chọn danh mục giao dịch.
class CategoryDropdownField extends StatelessWidget {
  /// Danh mục đang được chọn.
  final Category selectedCategory;

  /// Callback khi người dùng chọn danh mục mới.
  final ValueChanged<Category?> onChanged;

  /// Khởi tạo [CategoryDropdownField].
  const CategoryDropdownField({
    super.key,
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
              Icon(cat.icon, size: 20),
              const SizedBox(width: 8),
              Text(cat.label),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// Ô chọn ngày giao dịch qua DatePicker dialog.
class DatePickerField extends StatelessWidget {
  /// Ngày giao dịch hiện đang chọn.
  final DateTime selectedDate;

  /// Thông báo lỗi từ Domain Validation (nếu có).
  final String? errorText;

  /// Callback khi người dùng chọn ngày mới từ picker.
  final ValueChanged<DateTime> onDatePicked;

  /// Mốc ngày nhỏ nhất cho phép chọn trên picker (phục vụ demo kiểm thử).
  static final DateTime minDate = DateTime(1990);

  /// Mốc ngày lớn nhất cho phép chọn trên picker (phục vụ demo kiểm thử).
  static final DateTime maxDate = DateTime(2100);

  /// Khởi tạo [DatePickerField].
  const DatePickerField({
    super.key,
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
              firstDate: minDate,
              lastDate: maxDate,
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

/// Ô nhập văn bản ghi chú bổ sung.
class NoteInputField extends StatelessWidget {
  /// Controller quản lý ghi chú.
  final TextEditingController controller;

  /// Khởi tạo [NoteInputField].
  const NoteInputField({
    super.key,
    required this.controller,
  });

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
