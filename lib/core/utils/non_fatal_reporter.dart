/// Hàm callback ghi nhận các lỗi không gây gián đoạn luồng nghiệp vụ (Non-fatal errors).
///
/// **Lý do thiết kế:**
/// Trong kiến trúc xử lý lỗi tập trung, có những sự cố thứ cấp (ví dụ: ghi cache thất bại
/// khi đọc remote thành công, hoặc lỗi remote bị "nuốt" khi rơi về cache thành công)
/// không nên làm ngắt quãng trải nghiệm của người dùng (vẫn trả về `Success`).
/// `NonFatalErrorReporter` cung cấp cơ chế để Repository báo cáo các lỗi này trực tiếp
/// cho hệ thống giám sát / logging mà không phá vỡ hợp đồng dữ liệu trả về.
typedef NonFatalErrorReporter = void Function(
  Object error,
  StackTrace stackTrace, {
  String? source,
});
