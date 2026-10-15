import 'package:expense_tracker/core/errors/cache_storage_error.dart';
import 'package:expense_tracker/data/datasources/local_data_source.dart';
import 'package:expense_tracker/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('T-108: LocalDataSource Tests', () {
    late SharedPreferences prefs;
    late LocalDataSource localDataSource;
    final now = DateTime(2026, 10, 14, 15, 0);

    final sampleModel1 = TransactionModel(
      id: 'cached-1',
      type: 'income',
      title: 'Lương chuyển khoản',
      amount: 12000000,
      category: 'salary',
      date: now,
      createdAt: now,
    );

    final sampleModel2 = TransactionModel(
      id: 'cached-2',
      type: 'expense',
      title: 'Mua bánh mì',
      amount: 25000,
      category: 'food',
      date: now,
      createdAt: now,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      localDataSource = LocalDataSource(prefs);
    });

    test('1. Cache ban đầu rỗng -> getAll trả về danh sách rỗng []', () async {
      final items = await localDataSource.getAll();
      expect(items, isEmpty);
    });

    test('2. Thêm và tra cứu getById trong cache thành công', () async {
      await localDataSource.add(sampleModel1);
      await localDataSource.add(sampleModel2);

      final all = await localDataSource.getAll();
      expect(all.length, equals(2));
      expect(all[0].id, equals('cached-1'));
      expect(all[1].id, equals('cached-2'));

      final item = await localDataSource.getById('cached-1');
      expect(item.id, equals('cached-1'));
      expect(item.title, equals('Lương chuyển khoản'));
    });

    test('3. getById không tìm thấy -> Ném CacheStorageError', () async {
      expect(
        localDataSource.getById('non-existent-id'),
        throwsA(isA<CacheStorageError>()),
      );
    });

    test('4. Cập nhật (update) bản ghi trong cache thành công', () async {
      await localDataSource.add(sampleModel1);

      final updated = TransactionModel(
        id: 'cached-1',
        type: 'income',
        title: 'Lương thực nhận sau thuế',
        amount: 11500000,
        category: 'salary',
        date: now,
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );

      final result = await localDataSource.update(updated);
      expect(result.title, equals('Lương thực nhận sau thuế'));
      expect(result.amount, equals(11500000));

      final fetched = await localDataSource.getById('cached-1');
      expect(fetched.title, equals('Lương thực nhận sau thuế'));
    });

    test('5. update bản ghi không tồn tại -> Ném CacheStorageError', () async {
      expect(
        localDataSource.update(sampleModel1),
        throwsA(isA<CacheStorageError>()),
      );
    });

    test('6. Xóa (delete) bản ghi trong cache thành công', () async {
      await localDataSource.add(sampleModel1);
      await localDataSource.add(sampleModel2);

      await localDataSource.delete('cached-1');

      final remaining = await localDataSource.getAll();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('cached-2'));
    });

    test('7. delete bản ghi không tồn tại -> Ném CacheStorageError', () async {
      expect(
        localDataSource.delete('not-found-id'),
        throwsA(isA<CacheStorageError>()),
      );
    });

    test('8. replaceAll ghi đè toàn bộ dữ liệu trong cache', () async {
      await localDataSource.add(sampleModel1);

      final newBatch = [
        sampleModel2,
        TransactionModel(
          id: 'cached-3',
          type: 'expense',
          title: 'Đi xe bus',
          amount: 7000,
          category: 'transport',
          date: now,
          createdAt: now,
        ),
      ];

      await localDataSource.replaceAll(newBatch);

      final result = await localDataSource.getAll();
      expect(result.length, equals(2));
      expect(result[0].id, equals('cached-2'));
      expect(result[1].id, equals('cached-3'));
      expect(result.any((t) => t.id == 'cached-1'), isFalse);
    });

    test(
        '9. Dữ liệu trong storage bị hỏng cú pháp JSON -> Ném CacheStorageError',
        () async {
      // Giả lập dữ liệu trong SharedPreferences bị lưu chuỗi hỏng cú pháp
      await prefs.setString(
          LocalDataSource.storageKey, '{invalid json syntax}');

      expect(
        localDataSource.getAll(),
        throwsA(isA<CacheStorageError>()),
      );
    });

    test('10. Dữ liệu trong storage không phải List -> Ném CacheStorageError',
        () async {
      // Giả lập dữ liệu là JSON Map thay vì JSON List
      await prefs.setString(LocalDataSource.storageKey, '{"single": "object"}');

      expect(
        localDataSource.getAll(),
        throwsA(isA<CacheStorageError>()),
      );
    });

    test(
        '11. Dữ liệu phần tử bên trong bị sai schema -> Ném CacheStorageError (bọc lại ParseException)',
        () async {
      // Giả lập dữ liệu là List nhưng phần tử bị thiếu trường id
      await prefs.setString(LocalDataSource.storageKey, '[{"amount": 1000}]');

      expect(
        localDataSource.getAll(),
        throwsA(isA<CacheStorageError>()),
      );
    });
  });
}
