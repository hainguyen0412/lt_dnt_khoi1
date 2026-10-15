import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/utils/result.dart';
import '../repositories/transaction_repository.dart';

/// Ca sử dụng (Use Case): Xóa một giao dịch khỏi hệ thống theo [id].
///
/// **Quy tắc an toàn:**
/// Kiểm tra tính hợp lệ của [id]. Nếu [id] rỗng hoặc chỉ toàn khoảng trắng thừa,
/// trả về ngay `Failure(ValidationException)` mà không gọi xuống Repository.
class DeleteTransaction {
  final TransactionRepository _repository;

  /// Khởi tạo [DeleteTransaction] với [TransactionRepository].
  const DeleteTransaction(this._repository);

  /// Thực thi xóa giao dịch theo [id].
  Future<Result<void>> call(String id) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return Future.value(
        const Failure(
          ValidationException(
            field: 'id',
            message: 'Mã giao dịch không hợp lệ.',
          ),
        ),
      );
    }
    return _repository.delete(trimmedId);
  }
}
