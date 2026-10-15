import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../../core/errors/http_status_error.dart';
import '../../core/simulation/failure_mode.dart';
import '../../core/utils/loggable_mixin.dart';
import '../models/transaction_model.dart';
import 'data_source.dart';

/// Nguồn dữ liệu từ xa giả lập (Fake Remote Data Source) phục vụ kiểm thử và thuyết trình đồ án.
///
/// **Đặc điểm kiến trúc:**
/// 1. Lưu trữ dữ liệu mẫu trong bộ nhớ (In-memory list) với 7 giao dịch thu - chi thực tế.
/// 2. Giả lập độ trễ mạng thực tế 300 - 800ms (hàm [delayFn] cho phép tiêm từ bên ngoài để test chạy tức thì).
/// 3. Hỗ trợ mô phỏng ném các **lỗi thô (Raw Exceptions)** thông qua [FailureSimulator]:
///    - `FailureMode.network` -> [SocketException]
///    - `FailureMode.timeout` -> [TimeoutException]
///    - `FailureMode.server500` -> [HttpStatusError] (mã 500)
///    - `FailureMode.badJson` -> ném [ParseException] trực tiếp từ `TransactionModel.fromJson`
///    - `FailureMode.random` -> ngẫu nhiên một trong các lỗi trên hoặc thành công
/// 4. Tra cứu không tìm thấy bản ghi -> ném [HttpStatusError] (mã 404).
/// 5. Áp dụng [LoggableMixin] (R3) để ghi log vết thao tác mạng.
class FakeRemoteDataSource
    with LoggableMixin
    implements DataSource<TransactionModel> {
  final FailureSimulator _simulator;
  final Future<void> Function(Duration) _delayFn;
  final math.Random _random;

  final List<TransactionModel> _items = [];

  /// Khởi tạo [FakeRemoteDataSource].
  ///
  /// Cho phép tiêm [simulator], [delayFn], [random], và [initialData] để phục vụ kiểm thử cô lập.
  FakeRemoteDataSource({
    required FailureSimulator simulator,
    Future<void> Function(Duration)? delayFn,
    math.Random? random,
    List<TransactionModel>? initialData,
  })  : _simulator = simulator,
        _delayFn = delayFn ?? Future.delayed,
        _random = random ?? math.Random() {
    if (initialData != null) {
      _items.addAll(initialData);
    } else {
      _items.addAll(_createSampleTransactions());
    }
  }

  /// Mô phỏng độ trễ mạng (300ms - 800ms) trước khi thực thi yêu cầu.
  Future<void> _simulateLatency() async {
    final ms = 300 + _random.nextInt(501);
    await _delayFn(Duration(milliseconds: ms));
  }

  /// Kiểm tra và ném lỗi thô tương ứng với chế độ [FailureMode] hiện thời.
  void _maybeSimulateFailure() {
    switch (_simulator.mode) {
      case FailureMode.none:
        return;
      case FailureMode.network:
        logWarning('Simulating network failure: SocketException');
        throw const SocketException(
          'Failed to connect to host api.expensetracker.local: Network unreachable',
        );
      case FailureMode.timeout:
        logWarning('Simulating request timeout: TimeoutException');
        throw TimeoutException(
          'Request to remote server timed out after 5000ms',
        );
      case FailureMode.server500:
        logWarning('Simulating server error: HttpStatusError(500)');
        throw const HttpStatusError(
          500,
          'Internal Server Error: Database connection pool exhausted',
        );
      case FailureMode.badJson:
        logWarning('Simulating malformed JSON payload: ParseException');
        // Đưa dữ liệu JSON sai định dạng đi qua TransactionModel.fromJson thật
        TransactionModel.fromJson(const {
          'id': 99999, // Sai kiểu: id phải là String
          'type': 'invalid_type',
          'title': null,
          'amount': 'not_an_int',
        });
        return;
      case FailureMode.random:
        final modes = [
          FailureMode.none,
          FailureMode.network,
          FailureMode.timeout,
          FailureMode.server500,
          FailureMode.badJson,
        ];
        final picked = modes[_random.nextInt(modes.length)];
        if (picked != FailureMode.none) {
          _triggerSpecificFailure(picked);
        }
        return;
    }
  }

  void _triggerSpecificFailure(FailureMode mode) {
    switch (mode) {
      case FailureMode.network:
        throw const SocketException('Random network failure: Connection reset');
      case FailureMode.timeout:
        throw TimeoutException(
            'Random timeout: Server did not respond in time');
      case FailureMode.server500:
        throw const HttpStatusError(500, 'Random 500: Internal server error');
      case FailureMode.badJson:
        TransactionModel.fromJson(const {'invalid': 'bad_payload'});
        return;
      default:
        return;
    }
  }

  @override
  Future<List<TransactionModel>> getAll() async {
    logDebug('FakeRemoteDataSource.getAll() called');
    await _simulateLatency();
    _maybeSimulateFailure();
    return List.unmodifiable(_items);
  }

  @override
  Future<TransactionModel> getById(String id) async {
    logDebug('FakeRemoteDataSource.getById($id) called');
    await _simulateLatency();
    _maybeSimulateFailure();

    final item = _items.cast<TransactionModel?>().firstWhere(
          (t) => t?.id == id,
          orElse: () => null,
        );

    if (item == null) {
      throw HttpStatusError(
        404,
        'Transaction with id $id not found on remote server',
      );
    }
    return item;
  }

  @override
  Future<TransactionModel> add(TransactionModel item) async {
    logDebug('FakeRemoteDataSource.add(${item.id}) called');
    await _simulateLatency();
    _maybeSimulateFailure();

    _items.add(item);
    return item;
  }

  @override
  Future<TransactionModel> update(TransactionModel item) async {
    logDebug('FakeRemoteDataSource.update(${item.id}) called');
    await _simulateLatency();
    _maybeSimulateFailure();

    final index = _items.indexWhere((t) => t.id == item.id);
    if (index == -1) {
      throw HttpStatusError(
        404,
        'Cannot update: Transaction with id ${item.id} not found on remote server',
      );
    }

    _items[index] = item;
    return item;
  }

  @override
  Future<void> delete(String id) async {
    logDebug('FakeRemoteDataSource.delete($id) called');
    await _simulateLatency();
    _maybeSimulateFailure();

    final index = _items.indexWhere((t) => t.id == id);
    if (index == -1) {
      throw HttpStatusError(
        404,
        'Cannot delete: Transaction with id $id not found on remote server',
      );
    }

    _items.removeAt(index);
  }

  /// Danh sách 7 giao dịch mẫu khởi tạo ban đầu.
  static List<TransactionModel> _createSampleTransactions() {
    final baseTime = DateTime(2026, 10, 10, 9, 0, 0);

    return [
      TransactionModel(
        id: 'tx-sample-01',
        type: 'income',
        title: 'Nhận lương tháng 10',
        amount: 15000000,
        category: 'salary',
        date: baseTime,
        note: 'Lương chuyển khoản ngân hàng',
        createdAt: baseTime,
      ),
      TransactionModel(
        id: 'tx-sample-02',
        type: 'expense',
        title: 'Thanh toán tiền trọ',
        amount: 3500000,
        category: 'bills',
        date: baseTime.add(const Duration(hours: 2)),
        note: 'Tiền phòng + dịch vụ tháng 10',
        createdAt: baseTime.add(const Duration(hours: 2)),
      ),
      TransactionModel(
        id: 'tx-sample-03',
        type: 'expense',
        title: 'Mua thực phẩm siêu thị',
        amount: 450000,
        category: 'food',
        date: baseTime.add(const Duration(days: 1)),
        note: 'Rau củ, thịt cá, gia vị',
        createdAt: baseTime.add(const Duration(days: 1)),
      ),
      TransactionModel(
        id: 'tx-sample-04',
        type: 'expense',
        title: 'Đổ xăng xe máy',
        amount: 80000,
        category: 'transport',
        date: baseTime.add(const Duration(days: 2)),
        createdAt: baseTime.add(const Duration(days: 2)),
      ),
      TransactionModel(
        id: 'tx-sample-05',
        type: 'expense',
        title: 'Mua sách lập trình Flutter',
        amount: 250000,
        category: 'entertainment',
        date: baseTime.add(const Duration(days: 3)),
        note: 'Sách giáo trình tham khảo',
        createdAt: baseTime.add(const Duration(days: 3)),
      ),
      TransactionModel(
        id: 'tx-sample-06',
        type: 'expense',
        title: 'Khám sức khỏe tổng quát',
        amount: 600000,
        category: 'health',
        date: baseTime.add(const Duration(days: 3, hours: 4)),
        createdAt: baseTime.add(const Duration(days: 3, hours: 4)),
      ),
      TransactionModel(
        id: 'tx-sample-07',
        type: 'income',
        title: 'Thưởng đồ án môn học',
        amount: 2000000,
        category: 'salary',
        date: baseTime.add(const Duration(days: 4)),
        note: 'Thưởng hoàn thành xuất sắc đồ án',
        createdAt: baseTime.add(const Duration(days: 4)),
      ),
    ];
  }
}
