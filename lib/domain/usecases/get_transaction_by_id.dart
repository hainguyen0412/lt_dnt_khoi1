import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Ca sử dụng (Use Case): Lấy chi tiết một giao dịch theo định danh [id].
class GetTransactionById {
  final TransactionRepository _repository;

  /// Khởi tạo [GetTransactionById] với [TransactionRepository].
  const GetTransactionById(this._repository);

  /// Thực thi tra cứu giao dịch theo [id].
  ///
  /// Nếu [id] rỗng sau khi loại bỏ khoảng trắng, hàm trả về ngay [Failure]
  /// chứa [ValidationException] mà KHÔNG gọi xuống tầng Repository.
  Future<Result<Transaction>> call(String id) {
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
    return _repository.getById(trimmedId);
  }
}
