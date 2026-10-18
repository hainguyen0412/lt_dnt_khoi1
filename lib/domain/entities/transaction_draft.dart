import '../../core/errors/app_exception.dart';
import '../../core/utils/validatable_mixin.dart';
import '../validation/transaction_rules.dart';
import 'category.dart';
import 'money.dart';
import 'transaction.dart';
import 'transaction_type.dart';

/// Bản nháp giao dịch chứa dữ liệu đầu vào người dùng nhập từ biểu mẫu (Form Draft).
///
/// **Lý do thiết kế:**
/// 1. Tách biệt dữ liệu nhập liệu và thực thể lưu trữ: Khi người dùng đang tạo mới giao dịch,
///    chưa hề có `id` hay `createdAt`. Tách riêng `TransactionDraft` giúp tầng Presentation
///    không phải truyền các giá trị giả (dummy id/date) vào `Transaction`.
/// 2. Tái sử dụng ValidatableMixin (R3): Tận dụng `ValidatableMixin` để kiểm tra hợp lệ
///    ngay tại tầng form trước khi chuyển đổi sang entity chính thức qua [toTransaction].
class TransactionDraft with ValidatableMixin {
  /// Loại giao dịch (Thu nhập hoặc Chi phí).
  final TransactionType type;

  /// Tiêu đề giao dịch người dùng nhập.
  final String title;

  /// Số tiền giao dịch.
  final Money amount;

  /// Phân loại danh mục.
  final Category category;

  /// Ngày phát sinh giao dịch được chọn.
  final DateTime date;

  /// Ghi chú người dùng nhập (nếu có).
  final String? note;

  /// Khởi tạo một bản nháp giao dịch [TransactionDraft].
  const TransactionDraft({
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  /// Chuyển đổi bản nháp thành thực thể [Transaction] hoàn chỉnh.
  ///
  /// Nhận vào [id] được cấp phát và mốc thời gian tạo lập [now].
  Transaction toTransaction({
    required String id,
    required DateTime now,
  }) {
    return Transaction(
      id: id,
      type: type,
      title: title,
      amount: amount,
      category: category,
      date: date,
      note: note,
      createdAt: now,
      updatedAt: null,
    );
  }

  /// Tạo bản sao của bản nháp với các trường được thay đổi.
  TransactionDraft copyWith({
    TransactionType? type,
    String? title,
    Money? amount,
    Category? category,
    DateTime? date,
    String? note,
  }) {
    return TransactionDraft(
      type: type ?? this.type,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  @override
  List<ValidationException> validate() {
    return TransactionRules.validate(
      title: title,
      amount: amount,
      date: date,
    );
  }

  /// Kiểm tra tính hợp lệ với mốc thời gian [now] tùy biến (phục vụ test).
  List<ValidationException> validateWithNow(DateTime now) {
    return TransactionRules.validate(
      title: title,
      amount: amount,
      date: date,
      now: now,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionDraft &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title &&
          amount == other.amount &&
          category == other.category &&
          date == other.date &&
          note == other.note;

  @override
  int get hashCode => Object.hash(
        type,
        title,
        amount,
        category,
        date,
        note,
      );

  @override
  String toString() =>
      'TransactionDraft(type: $type, title: $title, amount: $amount, date: $date)';
}
