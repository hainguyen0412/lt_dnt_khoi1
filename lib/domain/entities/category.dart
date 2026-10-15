/// Danh mục phân loại giao dịch tài chính.
///
/// Các nhãn hiển thị tiếng Việt và biểu tượng thuộc tầng Presentation,
/// tầng Domain chỉ lưu trữ các định danh logic này.
enum Category {
  /// Ăn uống
  food,

  /// Đi lại / Di chuyển
  transport,

  /// Mua sắm
  shopping,

  /// Hóa đơn & Tiện ích
  bills,

  /// Y tế & Sức khỏe
  health,

  /// Giải trí
  entertainment,

  /// Lương & Thưởng
  salary,

  /// Khác
  other,
}
