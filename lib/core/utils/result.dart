import '../errors/app_exception.dart';

/// Kiểu dữ liệu đóng gói kết quả thực thi một thao tác có khả năng sinh lỗi.
///
/// **Lý do thiết kế `sealed class Result<T>`:**
/// Thay vì ném (throw) exception ra ngoài luồng điều khiển bình thường, Repository trả về `Result<T>`.
/// Cách tiếp cận này (Functional Error Handling) ép buộc tầng gọi (Caller) phải tường minh
/// xử lý cả hai khả năng: Thành công ([Success]) và Thất bại ([Failure]).
///
/// **Lý do viết method trực tiếp thay vì extension:**
/// 1. Tính đóng gói (Encapsulation): Các hành vi cốt lõi (`fold`, `map`, `getOrElse`) gắn liền
///    với trạng thái nội tại của đối tượng, được phân rã đa hình tự nhiên trên hai lớp con.
/// 2. Hỗ trợ IDE và Auto-completion: Các phương thức xuất hiện trực tiếp ngay khi gõ phím,
///    không phụ thuộc vào việc import đúng file extension.
/// 3. Dễ đọc hiểu và thuyết trình: Cấu trúc OOP kế thừa rõ ràng, không gây nhầm lẫn cú pháp
///    với giảng viên và thành viên trong nhóm.
sealed class Result<T> {
  const Result();

  /// Cho biết thao tác đã hoàn thành thành công hay chưa.
  bool get isSuccess;

  /// Cho biết thao tác có gặp thất bại hay không.
  bool get isFailure => !isSuccess;

  /// Rẽ nhánh xử lý kết quả dựa trên trạng thái thành công hoặc thất bại.
  ///
  /// Nhận vào [onSuccess] để xử lý dữ liệu [T] khi thành công,
  /// hoặc [onFailure] để xử lý [AppException] khi xảy ra lỗi.
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(AppException error) onFailure,
  );

  /// Biến đổi dữ liệu bên trong [Success] thông qua hàm [transform].
  ///
  /// Nếu đối tượng hiện tại là [Failure], phương thức giữ nguyên đối tượng [error]
  /// và chuyển đổi kiểu generic sang [Result<R>].
  Result<R> map<R>(R Function(T data) transform);

  /// Trả về dữ liệu [T] nếu thành công, hoặc giá trị dự phòng từ hàm [orElse] nếu thất bại.
  T getOrElse(T Function(AppException error) orElse);
}

/// Đại diện cho kết quả thành công, chứa dữ liệu [data] kiểu [T].
final class Success<T> extends Result<T> {
  /// Dữ liệu thu được sau thao tác thành công.
  final T data;

  /// Khởi tạo một đối tượng [Success] chứa [data].
  const Success(this.data);

  @override
  bool get isSuccess => true;

  @override
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(AppException error) onFailure,
  ) {
    return onSuccess(data);
  }

  @override
  Result<R> map<R>(R Function(T data) transform) {
    return Success<R>(transform(data));
  }

  @override
  T getOrElse(T Function(AppException error) orElse) {
    return data;
  }

  @override
  String toString() => 'Success($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// Đại diện cho kết quả thất bại, chứa ngoại lệ nghiệp vụ [error].
final class Failure<T> extends Result<T> {
  /// Ngoại lệ [AppException] mô tả lỗi gặp phải.
  final AppException error;

  /// Khởi tạo một đối tượng [Failure] chứa [error].
  const Failure(this.error);

  @override
  bool get isSuccess => false;

  @override
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(AppException error) onFailure,
  ) {
    return onFailure(error);
  }

  @override
  Result<R> map<R>(R Function(T data) transform) {
    return Failure<R>(error);
  }

  @override
  T getOrElse(T Function(AppException error) orElse) {
    return orElse(error);
  }

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}
