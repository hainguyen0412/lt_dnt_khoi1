import 'dart:async';

import '../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../entities/transaction_draft.dart';
import '../repositories/transaction_repository.dart';

/// Ca sử dụng (Use Case): Thêm mới một giao dịch từ dữ liệu người dùng nhập ([TransactionDraft]).
///
/// **Quy trình thực thi:**
/// 1. Kiểm tra tính hợp lệ của bản nháp thông qua `draft.ensureValid()`.
/// 2. Nếu vi phạm, ngắt luồng ngay lập tức và trả về `Failure(ValidationException)`
///    với lỗi đầu tiên (theo thứ tự `title` -> `amount` -> `date`), **tuyệt đối không gọi repository**.
/// 3. Nếu hợp lệ, chuyển đổi bản nháp sang thực thể `Transaction` với `id` sinh từ `_idGenerator`
///    và mốc thời gian tạo lập lấy từ `_clock`.
/// 4. Lưu vào kho dữ liệu thông qua `_repository.add(transaction)`.
class AddTransaction {
  final TransactionRepository _repository;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  /// Khởi tạo [AddTransaction].
  ///
  /// Cho phép tiêm [idGenerator] và [clock] từ bên ngoài nhằm phục vụ việc viết
  /// Unit Test hoàn toàn độc lập, không phụ thuộc vào đồng hồ hệ thống hay bộ sinh ID ngẫu nhiên.
  AddTransaction(
    this._repository, {
    String Function()? idGenerator,
    DateTime Function()? clock,
  })  : _idGenerator = idGenerator ?? _defaultIdGenerator,
        _clock = clock ?? _defaultClock;

  static String _defaultIdGenerator() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  static DateTime _defaultClock() => DateTime.now();

  /// Thực thi thêm mới giao dịch từ [draft].
  Future<Result<Transaction>> call(TransactionDraft draft) {
    // Bước 1: Kiểm tra hợp lệ dữ liệu đầu vào
    final validationResult = draft.ensureValid();
    if (validationResult.isFailure) {
      // Trả về lỗi vi phạm đầu tiên mà không gọi repository
      return Future.value(
        Failure<Transaction>((validationResult as Failure<void>).error),
      );
    }

    // Bước 2: Chuyển đổi thành Transaction hoàn chỉnh
    final transaction = draft.toTransaction(
      id: _idGenerator(),
      now: _clock(),
    );

    // Bước 3: Lưu thông qua Repository
    return _repository.add(transaction);
  }
}
