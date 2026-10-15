/// Đối tượng giá trị (Value Object) đại diện cho tiền tệ Việt Nam Đồng (VND).
///
/// **Lý do thiết kế Value Object:**
/// 1. Tính bất biến (Immutability): Đóng gói giá trị tiền tệ thành kiểu dữ liệu bất biến,
///    giúp việc tính toán và truyền tải giữa các tầng an toàn, tránh lỗi thay đổi trạng thái ngoài ý muốn.
/// 2. Lưu số nguyên đồng (int): Tiền tệ VND không có đơn vị xu/hào lẻ. Việc sử dụng số nguyên [int]
///    và tuyệt đối KHÔNG dùng `double` giúp loại bỏ hoàn toàn các lỗi sai số làm tròn dấu phẩy động
///    (floating-point precision issues) trong tính toán tài chính.
/// 3. Không ném ngoại lệ trong constructor: Constructor cho phép khởi tạo mọi giá trị số nguyên
///    (kể cả số âm) để tầng Domain/Validation có thể nhận diện và tạo `ValidationException` phản hồi
///    thân thiện về UI thay vì làm ứng dụng crash ngay lập tức khi người dùng nhập sai.
class Money implements Comparable<Money> {
  /// Số tiền tính theo đơn vị Đồng (VND).
  final int amount;

  /// Khởi tạo một đối tượng [Money] với số tiền [amount].
  const Money(this.amount);

  /// Khởi tạo đối tượng [Money] với giá trị bằng 0 đồng.
  ///
  /// Áp dụng **R1 (Named constructor)**.
  const Money.zero() : amount = 0;

  /// Cho biết số tiền có phải là số dương (> 0) hay không.
  bool get isPositive => amount > 0;

  /// Cộng hai khoản tiền, trả về một đối tượng [Money] mới.
  Money operator +(Money other) => Money(amount + other.amount);

  /// Trừ hai khoản tiền, trả về một đối tượng [Money] mới (có thể mang giá trị âm).
  Money operator -(Money other) => Money(amount - other.amount);

  @override
  int compareTo(Money other) => amount.compareTo(other.amount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amount == other.amount;

  @override
  int get hashCode => amount.hashCode;

  @override
  String toString() => '$amount VND';
}
