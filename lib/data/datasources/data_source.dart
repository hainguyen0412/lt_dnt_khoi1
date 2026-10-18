import 'dart:async';

/// Giao diện trừu tượng tổng quát (Generic Interface) định nghĩa các thao tác dữ liệu thô.
///
/// **HỢP ĐỒNG KỸ THUẬT (CONTRACT):**
/// 1. Tầng [DataSource] đóng vai trò giao tiếp trực tiếp với nguồn dữ liệu vật lý
///    (Network API, Disk Storage, SharedPreferences, In-Memory DB).
/// 2. **Các phương thức trong DataSource NÉM LỖI THÔ (Raw Exceptions)** khi gặp sự cố
///    (ví dụ: `SocketException`, `TimeoutException`, `HttpStatusError`, `CacheStorageError`,
///    hoặc `ParseException` từ `fromJson`).
/// 3. **DataSource TUYỆT ĐỐI KHÔNG trả về `Result<T>`.** Việc bắt ngoại lệ thô và chuẩn hóa thành
///    `Result<T>` chứa `AppException` là trách nhiệm duy nhất của tầng Repository (`TransactionRepositoryImpl`).
abstract interface class DataSource<T> {
  /// Lấy toàn bộ danh sách bản ghi [T] từ nguồn dữ liệu.
  Future<List<T>> getAll();

  /// Tra cứu chi tiết một bản ghi [T] theo định danh [id].
  Future<T> getById(String id);

  /// Thêm mới một bản ghi [item] vào nguồn dữ liệu.
  Future<T> add(T item);

  /// Cập nhật bản ghi [item] đã tồn tại.
  Future<T> update(T item);

  /// Xóa vĩnh viễn bản ghi theo định danh [id].
  Future<void> delete(String id);
}

/// Giao diện nguồn dữ liệu bộ nhớ đệm (Cache) mở rộng từ [DataSource].
///
/// Bổ sung phương thức [replaceAll] giúp đồng bộ nhanh toàn bộ danh sách dữ liệu
/// từ Remote xuống Cache mà không vi phạm nguyên lý Interface Segregation.
abstract interface class CacheDataSource<T> implements DataSource<T> {
  /// Ghi đè toàn bộ danh sách bản ghi hiện có trong bộ nhớ đệm bằng danh sách [items] mới.
  Future<void> replaceAll(List<T> items);
}
