import 'money.dart';

/// Thực thể thống kê tổng quan tình hình tài chính thu - chi.
///
/// **Lý do thiết kế:**
/// Đóng gói các chỉ số tổng hợp tài chính vào một đối tượng chuyên biệt thay vì
/// trả về nhiều biến rời rạc, giúp tầng Repository và Presentation giao tiếp mạch lạc.
class TransactionSummary {
  /// Tổng số tiền thu nhập.
  final Money totalIncome;

  /// Tổng số tiền chi tiêu.
  final Money totalExpense;

  /// Khởi tạo đối tượng [TransactionSummary] với [totalIncome] và [totalExpense].
  const TransactionSummary({
    required this.totalIncome,
    required this.totalExpense,
  });

  /// Số dư tài chính hiện tại (Số dư = Tổng thu - Tổng chi).
  ///
  /// Giá trị này có thể mang số âm nếu tổng chi lớn hơn tổng thu.
  Money get balance => totalIncome - totalExpense;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionSummary &&
          runtimeType == other.runtimeType &&
          totalIncome == other.totalIncome &&
          totalExpense == other.totalExpense;

  @override
  int get hashCode => Object.hash(totalIncome, totalExpense);

  @override
  String toString() =>
      'TransactionSummary(income: $totalIncome, expense: $totalExpense, balance: $balance)';
}
