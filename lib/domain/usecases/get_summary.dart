import 'dart:async';

import '../../core/utils/result.dart';
import '../entities/transaction_summary.dart';
import '../repositories/transaction_repository.dart';

/// Ca sử dụng (Use Case): Lấy dữ liệu tổng quan thu - chi và số dư tài chính.
class GetSummary {
  final TransactionRepository _repository;

  /// Khởi tạo [GetSummary] với [TransactionRepository].
  const GetSummary(this._repository);

  /// Thực thi lấy thông tin thống kê tài chính.
  Future<Result<TransactionSummary>> call() {
    return _repository.getSummary();
  }
}
