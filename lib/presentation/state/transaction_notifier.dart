import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/error_handling/error_handler.dart';
import '../../core/error_handling/user_facing_error.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/usecases/add_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/get_summary.dart';
import '../../domain/usecases/get_transaction_by_id.dart';
import '../../domain/usecases/get_transactions.dart';
import '../../domain/usecases/update_transaction.dart';
import 'transaction_state.dart';

/// Quản lý trạng thái giao diện và điều phối nghiệp vụ cho tính năng Sổ chi tiêu.
///
/// **Lý do thiết kế kiến trúc phân tách trạng thái (State Separation):**
/// 1. **Trạng thái danh sách ([listState]):** Đại diện cho dữ liệu toàn màn hình (`TransactionListState`).
/// 2. **Trạng thái thao tác form ([isSubmitting], [fieldErrors], [actionError]):** Tách biệt hoàn toàn
///    để khi người dùng thêm/sửa/xóa gặp lỗi (Validation, Server), dữ liệu form và màn hình danh sách
///    không bị reset hay giật lag.
/// 3. **Kênh lỗi [boundaryError] (ValueListenable):** Dành riêng cho `ErrorBoundary` (T-304) lắng nghe
///    và dựng fallback UI khi phát sinh sự cố nghiêm trọng, không làm ảnh hưởng tới SnackBar [actionError].
/// 4. **Bảo đảm R8 (try-catch-finally ở tầng UI):** Hàm [_run] sử dụng `finally` để bảo đảm cờ `isSubmitting`
///    luôn được tắt ngay cả khi usecase xảy ra ngoại lệ runtime bất ngờ.
/// 5. **Bảo đảm R11 (Centralized Error Pipeline):** Mọi lỗi (kể cả [ValidationException]) đều được đẩy qua
///    [ErrorHandler.handle] để ghi log đầy đủ trước khi hiển thị cho người dùng.
class TransactionNotifier extends ChangeNotifier {
  final GetTransactions _getTransactions;
  // ignore: unused_field
  final GetTransactionById _getTransactionById;
  final AddTransaction _addTransaction;
  final UpdateTransaction _updateTransaction;
  final DeleteTransaction _deleteTransaction;
  final GetSummary _getSummary;
  final ErrorHandler _errorHandler;

  // --- Trạng thái danh sách ---
  TransactionListState _listState = const TransactionListInitial();

  // --- Trạng thái thao tác form (thêm / sửa / xóa) ---
  bool _isSubmitting = false;
  final Map<String, String> _fieldErrors = {};
  UserFacingError? _actionError;

  // --- Kênh báo lỗi màn hình dành cho ErrorBoundary (T-304) ---
  final ValueNotifier<UserFacingError?> _boundaryErrorNotifier =
      ValueNotifier<UserFacingError?>(null);

  // --- Bộ nhớ hành động gần nhất phục vụ retryLast() ---
  Future<void> Function()? _lastAction;

  // --- Cờ đánh dấu đã dispose để tránh gọi notifyListeners() bất hợp lệ ---
  bool _isDisposed = false;

  /// Khởi tạo [TransactionNotifier] với đầy đủ các usecases và [ErrorHandler] được tiêm vào.
  TransactionNotifier({
    required GetTransactions getTransactions,
    required GetTransactionById getTransactionById,
    required AddTransaction addTransaction,
    required UpdateTransaction updateTransaction,
    required DeleteTransaction deleteTransaction,
    required GetSummary getSummary,
    required ErrorHandler errorHandler,
  })  : _getTransactions = getTransactions,
        _getTransactionById = getTransactionById,
        _addTransaction = addTransaction,
        _updateTransaction = updateTransaction,
        _deleteTransaction = deleteTransaction,
        _getSummary = getSummary,
        _errorHandler = errorHandler;

  // ================= GETTERS =================

  /// Trạng thái hiển thị danh sách giao dịch hiện tại.
  TransactionListState get listState => _listState;

  /// Cho biết có đang thực hiện gửi dữ liệu (thêm/sửa/xóa) hay không.
  bool get isSubmitting => _isSubmitting;

  /// Bảng ánh xạ lỗi validation của từng trường (Key là tên trường, Value là câu thông báo).
  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  /// Thông điệp lỗi cấp hành động để hiển thị SnackBar.
  UserFacingError? get actionError => _actionError;

  /// Kênh lắng nghe lỗi nghiêm trọng cấp màn hình dành riêng cho `ErrorBoundary`.
  ValueListenable<UserFacingError?> get boundaryError => _boundaryErrorNotifier;

  // ================= VÒNG ĐỜI & BẢO VỆ =================

  /// Gọi [notifyListeners] an toàn, ngăn chặn ngoại lệ khi Notifier đã bị dispose.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _boundaryErrorNotifier.dispose();
      super.dispose();
    }
  }

  // ================= QUẢN LÝ LỖI =================

  /// Ghi nhận một lỗi nghiêm trọng vào kênh [boundaryError].
  void reportBoundaryError(UserFacingError error) {
    if (!_isDisposed) {
      _boundaryErrorNotifier.value = error;
    }
  }

  /// Xóa lỗi trong kênh [boundaryError].
  void clearBoundaryError() {
    if (!_isDisposed && _boundaryErrorNotifier.value != null) {
      _boundaryErrorNotifier.value = null;
    }
  }

  /// Xóa lỗi hành động (SnackBar) hiện tại.
  void clearActionError() {
    if (_actionError != null) {
      _actionError = null;
      _safeNotifyListeners();
    }
  }

  /// Xóa thông báo lỗi validation.
  ///
  /// - Nếu truyền [field], chỉ xóa lỗi của riêng trường đó (phục vụ form input realtime ở T-303).
  /// - Nếu [field] là `null`, xóa toàn bộ lỗi validation của tất cả các trường.
  void clearFieldErrors([String? field]) {
    if (field != null) {
      if (_fieldErrors.containsKey(field)) {
        _fieldErrors.remove(field);
        _safeNotifyListeners();
      }
    } else {
      if (_fieldErrors.isNotEmpty) {
        _fieldErrors.clear();
        _safeNotifyListeners();
      }
    }
  }

  // ================= HÀM BỌC AN TOÀN R8 =================

  /// Thực thi một hành động bất đồng bộ với cơ chế bọc bảo vệ `try-catch-finally`.
  ///
  /// **Mục đích thực tế của finally (R8):**
  /// Luôn bảo đảm reset cờ [isSubmitting] về `false` và kích hoạt [_safeNotifyListeners]
  /// ngay cả khi usecase bên dưới gặp sự cố runtime chưa được lường trước.
  Future<T?> _run<T>({
    required Future<T> Function() action,
    bool setSubmitting = false,
    bool setLoading = false,
  }) async {
    if (_isDisposed) return null;

    if (setSubmitting) {
      _isSubmitting = true;
      _safeNotifyListeners();
    }

    if (setLoading) {
      _listState = const TransactionListLoading();
      _safeNotifyListeners();
    }

    try {
      return await action();
    } catch (error, stackTrace) {
      // Bắt ngoại lệ bất ngờ (bug ở tầng dưới throw thay vì trả Result.failure)
      final userFacing = await _errorHandler.handle(
        error,
        stackTrace,
        source: 'TransactionNotifier',
      );
      reportBoundaryError(userFacing);
      if (_listState is TransactionListLoading) {
        _listState = TransactionListError(error: userFacing);
      }
      return null;
    } finally {
      if (setSubmitting) {
        _isSubmitting = false;
      }
      _safeNotifyListeners();
    }
  }

  /// Xử lý ngoại lệ phát sinh từ các thao tác ghi dữ liệu (add/update/delete).
  ///
  /// Tất cả lỗi đều đi qua [ErrorHandler] để chuẩn hóa và ghi log tập trung (R11).
  /// Nếu là [ValidationException] có trường cụ thể thì đưa vào [_fieldErrors],
  /// ngược lại thì gán vào [_actionError] để hiển thị qua SnackBar (R10).
  Future<void> _handleActionFailure(AppException error) async {
    final userError = await _errorHandler.handle(
      error,
      error.stackTrace ?? StackTrace.current,
      source: 'TransactionNotifier',
    );

    if (error is ValidationException && error.field != null) {
      _fieldErrors[error.field!] = userError.message;
    } else {
      _actionError = userError;
    }
  }

  /// Trích xuất dữ liệu danh sách trước đó nếu có để bảo tồn UI khi reload gặp lỗi.
  (List<Transaction>?, TransactionSummary?) _getPreviousData() {
    return switch (_listState) {
      TransactionListLoaded(:final items, :final summary) => (items, summary),
      TransactionListError(:final previousItems, :final previousSummary) => (
          previousItems,
          previousSummary
        ),
      _ => (null, null),
    };
  }

  /// Đặt trạng thái lỗi cho danh sách kèm dữ liệu trước đó để dự phòng offline.
  Future<void> _setListError(
    AppException error, {
    List<Transaction>? previousItems,
    TransactionSummary? previousSummary,
  }) async {
    final userError = await _errorHandler.handle(
      error,
      error.stackTrace ?? StackTrace.current,
      source: 'TransactionNotifier',
    );
    _listState = TransactionListError(
      error: userError,
      previousItems: previousItems,
      previousSummary: previousSummary,
    );
  }

  // ================= CÁC THAO TÁC NGHIỆP VỤ =================

  /// Tải danh sách giao dịch và thông tin tổng kết tài chính từ Repository.
  Future<void> load() async {
    _lastAction = () => load();
    await _loadInternal();
  }

  /// Logic tải dữ liệu nội bộ không ghi đè lại [_lastAction] của thao tác khác khi reload.
  Future<void> _loadInternal() async {
    await _run(
      setLoading: true,
      action: () async {
        final (previousItems, previousSummary) = _getPreviousData();

        final transactionsResult = await _getTransactions();
        if (transactionsResult.isFailure) {
          final failure = transactionsResult as Failure<List<Transaction>>;
          await _setListError(
            failure.error,
            previousItems: previousItems,
            previousSummary: previousSummary,
          );
          return;
        }

        final summaryResult = await _getSummary();
        if (summaryResult.isFailure) {
          final failure = summaryResult as Failure<TransactionSummary>;
          await _setListError(
            failure.error,
            previousItems: previousItems,
            previousSummary: previousSummary,
          );
          return;
        }

        final items = (transactionsResult as Success<List<Transaction>>).data;
        final summary = (summaryResult as Success<TransactionSummary>).data;

        if (items.isEmpty) {
          _listState = const TransactionListEmpty();
        } else {
          _listState = TransactionListLoaded(items: items, summary: summary);
        }
      },
    );
  }

  /// Thêm mới một giao dịch từ dữ liệu người dùng nhập ([draft]).
  ///
  /// Trả về `true` nếu thêm thành công và đã reload danh sách, `false` nếu thất bại.
  Future<bool> add(TransactionDraft draft) async {
    _lastAction = () => add(draft);
    clearActionError();
    clearFieldErrors();

    final result = await _run<bool>(
      setSubmitting: true,
      action: () async {
        final res = await _addTransaction(draft);
        if (res.isFailure) {
          final failure = res as Failure<Transaction>;
          await _handleActionFailure(failure.error);
          return false;
        }

        _lastAction = () => load();
        await _loadInternal();
        return true;
      },
    );

    return result ?? false;
  }

  /// Cập nhật thông tin của một [transaction] đã có.
  ///
  /// Trả về `true` nếu cập nhật thành công, `false` nếu thất bại.
  Future<bool> update(Transaction transaction) async {
    _lastAction = () => update(transaction);
    clearActionError();
    clearFieldErrors();

    final result = await _run<bool>(
      setSubmitting: true,
      action: () async {
        final res = await _updateTransaction(transaction);
        if (res.isFailure) {
          final failure = res as Failure<Transaction>;
          await _handleActionFailure(failure.error);
          return false;
        }

        _lastAction = () => load();
        await _loadInternal();
        return true;
      },
    );

    return result ?? false;
  }

  /// Xóa giao dịch theo định danh [id].
  ///
  /// Trả về `true` nếu xóa thành công, `false` nếu thất bại.
  Future<bool> delete(String id) async {
    _lastAction = () => delete(id);
    clearActionError();

    final result = await _run<bool>(
      setSubmitting: true,
      action: () async {
        final res = await _deleteTransaction(id);
        if (res.isFailure) {
          final failure = res as Failure<void>;
          await _handleActionFailure(failure.error);
          return false;
        }

        _lastAction = () => load();
        await _loadInternal();
        return true;
      },
    );

    return result ?? false;
  }

  /// Thử lại hành động gần nhất đã thất bại.
  ///
  /// Tự động xóa [boundaryError] trước khi thực thi lại.
  Future<void> retryLast() async {
    clearBoundaryError();
    final action = _lastAction;
    if (action != null) {
      await action();
    }
  }
}
