/// Mixin quản lý các mốc thời gian tạo lập và cập nhật của thực thể dữ liệu.
///
/// **Lý do thiết kế:**
/// 1. Tính nhất quán (Consistency): Đồng nhất cách quản lý thời gian trên toàn bộ các lớp dữ liệu
///    (Domain Entity như `Transaction` và Data Model như `TransactionModel`).
/// 2. Hỗ trợ đồng bộ và giải quyết xung đột: Cung cấp sẵn logic xác định phiên bản mới nhất
///    thông qua [lastModified] và phương thức so sánh mốc thời gian [isNewerThan].
mixin TimestampMixin {
  /// Thời điểm bản ghi được tạo lập lần đầu tiên.
  DateTime get createdAt;

  /// Thời điểm bản ghi được sửa đổi gần nhất (nếu có).
  DateTime? get updatedAt;

  /// Mốc thời gian sửa đổi cuối cùng của thực thể.
  ///
  /// Ưu tiên lấy [updatedAt]; nếu chưa từng được cập nhật thì lấy [createdAt].
  DateTime get lastModified => updatedAt ?? createdAt;

  /// So sánh xem đối tượng hiện tại có mốc sửa đổi mới hơn [other] hay không.
  bool isNewerThan(TimestampMixin other) =>
      lastModified.isAfter(other.lastModified);
}
