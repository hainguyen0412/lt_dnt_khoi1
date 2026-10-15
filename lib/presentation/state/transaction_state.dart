import '../../core/error_handling/user_facing_error.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_summary.dart';

/// Đại diện cho trạng thái của danh sách giao dịch trên giao diện chính.
///
/// **Lý do thiết kế Sealed Class (Dart 3.x):**
/// - Đảm bảo tính vét cạn (exhaustive pattern matching) khi render UI tại `TransactionListView`.
/// - Tách biệt hoàn toàn trạng thái hiển thị danh sách với trạng thái thao tác form (`isSubmitting`, `fieldErrors`).
sealed class TransactionListState {
  const TransactionListState();
}

/// Trạng thái khởi tạo ban đầu khi chưa thực hiện bất kỳ truy vấn nào.
final class TransactionListInitial extends TransactionListState {
  const TransactionListInitial();
}

/// Trạng thái đang tải danh sách giao dịch (hiển thị Shimmer hoặc Loading Spinner).
final class TransactionListLoading extends TransactionListState {
  const TransactionListLoading();
}

/// Trạng thái tải dữ liệu thành công và có ít nhất 1 bản ghi giao dịch.
final class TransactionListLoaded extends TransactionListState {
  /// Danh sách các giao dịch được hiển thị.
  final List<Transaction> items;

  /// Thống kê tài chính tổng quan (tổng thu, tổng chi, số dư).
  final TransactionSummary summary;

  const TransactionListLoaded({
    required this.items,
    required this.summary,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionListLoaded &&
        other.summary == summary &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), summary);

  static bool _listEquals(List<Transaction> a, List<Transaction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Trạng thái truy vấn thành công nhưng kho dữ liệu hoàn toàn rỗng (0 giao dịch).
final class TransactionListEmpty extends TransactionListState {
  const TransactionListEmpty();
}

/// Trạng thái tải danh sách giao dịch thất bại.
///
/// **Lưu ý thiết kế Offline-first & Graceful Degradation:**
/// Cho phép lưu giữ lại [previousItems] và [previousSummary] nếu trước đó đã có dữ liệu.
/// Nhờ vậy, khi gặp lỗi mạng lúc pull-to-refresh, UI vẫn hiển thị danh sách cũ kèm SnackBar cảnh báo
/// thay vì làm mất trắng toàn bộ màn hình của người dùng.
final class TransactionListError extends TransactionListState {
  /// Đối tượng lỗi thân thiện đã được xử lý qua Centralized Error Pipeline.
  final UserFacingError error;

  /// Danh sách giao dịch trước đó (nếu có).
  final List<Transaction>? previousItems;

  /// Thống kê tài chính trước đó (nếu có).
  final TransactionSummary? previousSummary;

  const TransactionListError({
    required this.error,
    this.previousItems,
    this.previousSummary,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionListError &&
        other.error == error &&
        other.previousSummary == previousSummary &&
        _nullableListEquals(other.previousItems, previousItems);
  }

  @override
  int get hashCode => Object.hash(
        error,
        previousSummary,
        previousItems == null ? null : Object.hashAll(previousItems!),
      );

  static bool _nullableListEquals(List<Transaction>? a, List<Transaction>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
