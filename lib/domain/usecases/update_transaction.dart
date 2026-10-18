import 'dart:async';

import '../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Ca sử dụng (Use Case): Cập nhật thông tin của một giao dịch đã tồn tại.
///
/// **Quy trình thực thi:**
/// 1. Kiểm tra tính hợp lệ của giao dịch thông qua `transaction.ensureValid()`.
/// 2. Nếu vi phạm, trả về `Failure(ValidationException)` và **không gọi repository**.
/// 3. Nếu hợp lệ, tạo bản sao mới với thuộc tính `updatedAt` được cập nhật từ `_clock()`.
/// 4. Thực thi lưu qua `_repository.update(...)`.
class UpdateTransaction {
  final TransactionRepository _repository;
  final DateTime Function() _clock;

  /// Khởi tạo [UpdateTransaction] với [TransactionRepository] và [clock] tùy chọn.
  UpdateTransaction(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  static DateTime _defaultClock() => DateTime.now();

  /// Thực thi cập nhật [transaction].
  Future<Result<Transaction>> call(Transaction transaction) {
    // Bước 1: Thẩm định hợp lệ
    final validationResult = transaction.ensureValid();
    if (validationResult.isFailure) {
      return Future.value(
        Failure<Transaction>((validationResult as Failure<void>).error),
      );
    }

    // Bước 2: Cập nhật mốc thời gian sửa đổi (updatedAt)
    final updatedTransaction = transaction.copyWith(
      updatedAt: _clock(),
    );

    // Bước 3: Ghi xuống Repository
    return _repository.update(updatedTransaction);
  }
}
