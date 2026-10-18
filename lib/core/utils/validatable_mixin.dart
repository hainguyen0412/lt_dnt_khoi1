import '../errors/app_exception.dart';
import 'result.dart';

/// Mixin quy định hành vi xác thực tính hợp lệ cho các đối tượng mô hình (Entity, DTO, Form Draft).
///
/// **Lý do thiết kế:**
/// 1. Chuẩn hóa quy trình kiểm tra dữ liệu: Mọi đối tượng có dữ liệu đầu vào cần xác thực
///    chỉ cần triển khai một phương thức duy nhất [validate].
/// 2. Tích hợp sẵn với `Result<void>`: Thay vì ném lỗi hoặc trả về boolean đơn thuần,
///    [ensureValid] trả về một `Result<void>` chứa đối tượng [ValidationException] đầu tiên,
///    giúp dễ dàng kết hợp vào các pipeline xử lý lỗi hàm thuần (functional style).
mixin ValidatableMixin {
  /// Danh sách toàn bộ các lỗi xác thực dữ liệu của đối tượng.
  ///
  /// Nếu đối tượng hoàn toàn hợp lệ, phương thức này phải trả về một danh sách rỗng `[]`.
  List<ValidationException> validate();

  /// Cho biết toàn bộ dữ liệu của đối tượng có hợp lệ hay không.
  bool get isValid => validate().isEmpty;

  /// Trả về lỗi vi phạm hợp lệ đầu tiên nếu có, ngược lại trả về `null`.
  ValidationException? get firstError => validate().firstOrNull;

  /// Đảm bảo đối tượng hợp lệ dưới dạng [Result<void>].
  ///
  /// - Trả về [Success(null)] nếu không có bất kỳ lỗi nào.
  /// - Trả về [Failure(firstError)] chứa ngoại lệ xác thực đầu tiên nếu phát hiện lỗi.
  Result<void> ensureValid() {
    final error = firstError;
    if (error == null) {
      return const Success(null);
    }
    return Failure(error);
  }
}
