import '../../core/errors/app_exception.dart';
import '../entities/money.dart';

/// Bộ quy tắc nghiệp vụ dùng chung để kiểm tra tính hợp lệ của giao dịch.
///
/// **Lý do thiết kế Static Pure Functions:**
/// 1. Nguyên lý DRY (Don't Repeat Yourself): Cả `Transaction` (thực thể bất biến đã lưu)
///    và `TransactionDraft` (bản nháp người dùng đang nhập trên form) đều có chung các tiêu chuẩn
///    nghiệp vụ. Việc tập trung quy tắc vào một class tiện ích giúp tránh lặp code.
/// 2. Dễ dàng kiểm thử độc lập (Testability): Hàm thuần (pure function) nhận vào tham số thời gian [now],
///    giúp viết unit test kiểm tra các mốc ngày biên mà không phụ thuộc vào đồng hồ hệ thống.
/// 3. Thứ tự kiểm tra cố định: Luôn kiểm tra theo trình tự `title` -> `amount` -> `date`
///    để đảm bảo tính nhất quán của thông báo lỗi đầu tiên ([ValidatableMixin.firstError]).
class TransactionRules {
  const TransactionRules._();

  /// Tên trường định danh tiêu đề giao dịch.
  static const String fieldTitle = 'title';

  /// Tên trường định danh số tiền giao dịch.
  static const String fieldAmount = 'amount';

  /// Tên trường định danh ngày phát sinh giao dịch.
  static const String fieldDate = 'date';

  /// Năm tối thiểu được chấp nhận cho một giao dịch.
  static const int minYear = 2000;

  /// Khoảng thời gian dung sai tương lai cho phép do lệch múi giờ (1 ngày).
  static const Duration maxFutureTolerance = Duration(days: 1);

  /// Kiểm tra các ràng buộc nghiệp vụ cho dữ liệu giao dịch.
  ///
  /// Danh sách kiểm tra theo thứ tự:
  /// 1. `title`: Không được rỗng sau khi loại bỏ khoảng trắng thừa.
  /// 2. `amount`: Số tiền phải là số nguyên dương lớn hơn 0.
  /// 3. `date`: Không được sau [now] quá 1 ngày và không được trước năm 2000.
  static List<ValidationException> validate({
    required String title,
    required Money amount,
    required DateTime date,
    DateTime? now,
  }) {
    final errors = <ValidationException>[];

    // Quy tắc 1: Tiêu đề giao dịch
    if (title.trim().isEmpty) {
      errors.add(
        const ValidationException(
          field: fieldTitle,
          message: 'Tiêu đề giao dịch không được để trống.',
        ),
      );
    }

    // Quy tắc 2: Số tiền
    if (amount.amount <= 0) {
      errors.add(
        const ValidationException(
          field: fieldAmount,
          message: 'Số tiền phải là số nguyên dương lớn hơn 0.',
        ),
      );
    }

    // Quy tắc 3: Ngày giao dịch
    final currentTime = now ?? DateTime.now();
    final maxAllowedDate = currentTime.add(maxFutureTolerance);

    if (date.isAfter(maxAllowedDate) || date.year < minYear) {
      errors.add(
        const ValidationException(
          field: fieldDate,
          message: 'Ngày giao dịch không hợp lệ (từ năm 2000 đến hiện tại).',
        ),
      );
    }

    return List.unmodifiable(errors);
  }
}
