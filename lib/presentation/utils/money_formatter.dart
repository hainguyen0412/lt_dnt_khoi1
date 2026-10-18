import 'package:intl/intl.dart';

import '../../domain/entities/money.dart';
import '../../domain/entities/transaction_type.dart';

/// Tiện ích định dạng tiền tệ Việt Nam Đồng (VND) và ngày tháng cho tầng giao diện.
///
/// **Lý do đặt tại Presentation Layer:**
/// Tầng Domain tuyệt đối không import các thư viện bên thứ ba như `intl`.
/// Do đó, việc định dạng số nguyên đồng sang chuỗi hiển thị chuẩn Việt Nam (`#,### ₫`)
/// được quy định thống nhất tại [MoneyFormatter].
class MoneyFormatter {
  const MoneyFormatter._();

  static final NumberFormat _vndFormat = NumberFormat('#,###', 'vi_VN');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  /// Định dạng số tiền nguyên sang định dạng VND (ví dụ: `45000` -> `"45.000 ₫"`).
  static String formatVnd(int amount) {
    if (amount == 0) return '0 ₫';
    return '${_vndFormat.format(amount)} ₫';
  }

  /// Định dạng đối tượng [Money] sang chuỗi VND.
  static String formatMoney(Money money) {
    return formatVnd(money.amount);
  }

  /// Định dạng số tiền kèm tiền tố dấu (+ / -) phục vụ Accessibility.
  ///
  /// **Tiêu chuẩn Tiếp cận (a11y):**
  /// Phân biệt Thu / Chi bằng cả ký hiệu toán học tường minh, không dựa hoàn toàn vào màu sắc:
  /// - Thu nhập ([TransactionType.income]): `"+ 10.000.000 ₫"`
  /// - Chi tiêu ([TransactionType.expense]): `"- 45.000 ₫"`
  static String formatWithSign(Money money, TransactionType type) {
    final formatted = formatVnd(money.amount.abs());
    return type == TransactionType.income ? '+ $formatted' : '- $formatted';
  }

  /// Định dạng mốc thời gian sang định dạng hiển thị thân thiện `"dd/MM/yyyy"`.
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
}
