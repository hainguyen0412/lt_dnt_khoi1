import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/cache_storage_error.dart';
import '../../core/utils/loggable_mixin.dart';
import '../models/transaction_model.dart';
import 'data_source.dart';

/// Nguồn dữ liệu bộ nhớ đệm cục bộ (Local Cache Data Source) sử dụng SharedPreferences.
///
/// **Lý do thiết kế:**
/// 1. Tối ưu và đơn giản: Lưu trữ danh sách giao dịch tuần tự hóa dưới dạng chuỗi JSON
///    vào một key duy nhất ([storageKey]). Giải pháp này hoàn toàn đáp ứng nhu cầu lưu trữ
///    của ứng dụng demo mà không cần cấu hình phức tạp như SQLite (`sqflite`).
/// 2. Nguyên tắc đóng gói ngoại lệ (Exception Safety): MỌI lỗi đọc/ghi/giải mã cache
///    (kể cả chuỗi JSON lưu dưới đĩa bị hỏng cấu trúc) đều được bắt lại và ném ra
///    dưới dạng [CacheStorageError]. Tuyệt đối không để lọt `FormatException` hay `ParseException` trần ra ngoài.
/// 3. Triển khai [CacheDataSource]: Hỗ trợ thao tác [replaceAll] giúp đồng bộ đè dữ liệu nhanh chóng từ Remote.
class LocalDataSource
    with LoggableMixin
    implements CacheDataSource<TransactionModel> {
  /// Khóa định danh lưu trữ danh sách giao dịch trong SharedPreferences.
  static const String storageKey = 'cached_transactions_v1';

  final SharedPreferences _prefs;

  /// Khởi tạo [LocalDataSource] với đối tượng [SharedPreferences] được tiêm vào.
  LocalDataSource(this._prefs);

  @override
  Future<List<TransactionModel>> getAll() async {
    logDebug('LocalDataSource.getAll() called');
    try {
      final rawJson = _prefs.getString(storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return [];
      }

      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        throw const CacheStorageError(
          'Corrupted cache: Expected a JSON List but got different type',
        );
      }

      final list = <TransactionModel>[];
      for (final rawItem in decoded) {
        list.add(TransactionModel.fromJson(rawItem));
      }
      return List.unmodifiable(list);
    } catch (e) {
      if (e is CacheStorageError) rethrow;
      logWarning('Failed to read cached transactions: $e');
      throw CacheStorageError(
          'Failed to read or decode cached transactions', e);
    }
  }

  @override
  Future<TransactionModel> getById(String id) async {
    logDebug('LocalDataSource.getById($id) called');
    final items = await getAll();
    final item = items.cast<TransactionModel?>().firstWhere(
          (t) => t?.id == id,
          orElse: () => null,
        );

    if (item == null) {
      throw CacheStorageError(
          'Transaction with id $id not found in local cache');
    }
    return item;
  }

  @override
  Future<TransactionModel> add(TransactionModel item) async {
    logDebug('LocalDataSource.add(${item.id}) called');
    final items = (await getAll()).toList();
    items.add(item);
    await _persistList(items);
    return item;
  }

  @override
  Future<TransactionModel> update(TransactionModel item) async {
    logDebug('LocalDataSource.update(${item.id}) called');
    final items = (await getAll()).toList();
    final index = items.indexWhere((t) => t.id == item.id);

    if (index == -1) {
      throw CacheStorageError(
        'Cannot update: Transaction with id ${item.id} not found in local cache',
      );
    }

    items[index] = item;
    await _persistList(items);
    return item;
  }

  @override
  Future<void> delete(String id) async {
    logDebug('LocalDataSource.delete($id) called');
    final items = (await getAll()).toList();
    final index = items.indexWhere((t) => t.id == id);

    if (index == -1) {
      throw CacheStorageError(
        'Cannot delete: Transaction with id $id not found in local cache',
      );
    }

    items.removeAt(index);
    await _persistList(items);
  }

  @override
  Future<void> replaceAll(List<TransactionModel> items) async {
    logDebug('LocalDataSource.replaceAll(${items.length} items) called');
    await _persistList(items);
  }

  /// Tuần tự hóa danh sách [items] sang JSON String và lưu vào SharedPreferences.
  Future<void> _persistList(List<TransactionModel> items) async {
    try {
      final jsonList = items.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      final success = await _prefs.setString(storageKey, jsonString);

      if (!success) {
        throw const CacheStorageError(
          'Failed to write data to SharedPreferences (storage returned false)',
        );
      }
    } catch (e) {
      if (e is CacheStorageError) rethrow;
      throw CacheStorageError('Failed to serialize and write to cache', e);
    }
  }
}
