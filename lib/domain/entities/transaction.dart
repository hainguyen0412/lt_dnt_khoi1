import '../../core/errors/app_exception.dart';
import '../../core/utils/timestamp_mixin.dart';
import '../../core/utils/validatable_mixin.dart';
import '../validation/transaction_rules.dart';
import 'category.dart';
import 'money.dart';
import 'transaction_type.dart';

/// Thực thể nghiệp vụ đại diện cho một bản ghi giao dịch thu - chi.
///
/// **Lý do thiết kế:**
/// 1. Tính bất biến (Immutable Entity): Mọi trường dữ liệu đều là `final`, ngăn chặn việc thay đổi
///    trạng thái trực tiếp từ bên ngoài. Thay đổi dữ liệu phải thông qua hàm [copyWith].
/// 2. Áp dụng Mixins (R3): Tái sử dụng `TimestampMixin` để quản lý thời gian tạo/sửa
///    và `ValidatableMixin` để kiểm tra các ràng buộc nghiệp vụ.
/// 3. Named Constructors (R1): Cung cấp `Transaction.income` và `Transaction.expense`
///    giúp code khởi tạo tường minh, tránh nhầm lẫn loại giao dịch.
class Transaction with TimestampMixin, ValidatableMixin {
  /// Mã định danh duy nhất của giao dịch (UUID/chuỗi định danh).
  final String id;

  /// Loại giao dịch (Thu nhập hoặc Chi phí).
  final TransactionType type;

  /// Tiêu đề / Mô tả ngắn gọn về khoản chi tiêu.
  final String title;

  /// Số tiền giao dịch (đơn vị VND, kiểu [Money]).
  final Money amount;

  /// Phân loại danh mục chi tiêu (Ăn uống, Đi lại...).
  final Category category;

  /// Ngày phát sinh giao dịch.
  final DateTime date;

  /// Ghi chú chi tiết bổ sung (tùy chọn).
  final String? note;

  @override
  final DateTime createdAt;

  @override
  final DateTime? updatedAt;

  /// Khởi tạo một đối tượng [Transaction] đầy đủ thông tin.
  const Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  /// Khởi tạo giao dịch Thu nhập ([TransactionType.income]).
  ///
  /// Áp dụng **R1 (Named constructor)**.
  const Transaction.income({
    required String id,
    required String title,
    required Money amount,
    required Category category,
    required DateTime date,
    String? note,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) : this(
          id: id,
          type: TransactionType.income,
          title: title,
          amount: amount,
          category: category,
          date: date,
          note: note,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// Khởi tạo giao dịch Chi tiêu ([TransactionType.expense]).
  ///
  /// Áp dụng **R1 (Named constructor)**.
  const Transaction.expense({
    required String id,
    required String title,
    required Money amount,
    required Category category,
    required DateTime date,
    String? note,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) : this(
          id: id,
          type: TransactionType.expense,
          title: title,
          amount: amount,
          category: category,
          date: date,
          note: note,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// Tạo một bản sao của giao dịch hiện tại với các trường được cập nhật.
  Transaction copyWith({
    String? id,
    TransactionType? type,
    String? title,
    Money? amount,
    Category? category,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

  /// Kiểm tra tính hợp lệ với mốc thời gian [now] truyền vào (phục vụ test).
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
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          amount == other.amount &&
          category == other.category &&
          date == other.date &&
          note == other.note &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        title,
        amount,
        category,
        date,
        note,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'Transaction(id: $id, type: $type, title: $title, amount: $amount, date: $date)';
}
