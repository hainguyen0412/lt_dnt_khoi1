import 'dart:async';

import '../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Ca sử dụng (Use Case): Lấy toàn bộ danh sách giao dịch thu - chi.
///
/// **Lý do thiết kế Callable Class (Command Pattern):**
/// Mỗi ca sử dụng đại diện cho một hành động nghiệp vụ cụ thể duy nhất (Single Responsibility Principle).
/// Phương thức [call] cho phép instance của class được gọi trực tiếp như một hàm (e.g. `getTransactions()`).
class GetTransactions {
  final TransactionRepository _repository;

  /// Khởi tạo [GetTransactions] với [TransactionRepository] được tiêm vào (Dependency Injection).
  const GetTransactions(this._repository);

  /// Thực thi ca sử dụng lấy danh sách giao dịch.
  Future<Result<List<Transaction>>> call() {
    return _repository.getAll();
  }
}
