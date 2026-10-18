import 'dart:async';
import 'dart:io';

import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/errors/http_status_error.dart';
import 'package:expense_tracker/core/simulation/failure_mode.dart';
import 'package:expense_tracker/data/datasources/fake_remote_data_source.dart';
import 'package:expense_tracker/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-107: FakeRemoteDataSource Tests', () {
    late FailureSimulator simulator;
    late FakeRemoteDataSource dataSource;

    setUp(() {
      simulator = FailureSimulator(FailureMode.none);
      // Tiêm delayFn không chờ để test thực thi ngay lập tức
      dataSource = FakeRemoteDataSource(
        simulator: simulator,
        delayFn: (_) async {},
      );
    });

    test('1. Chế độ none: getAll trả về 7 bản ghi mẫu thực tế', () async {
      final items = await dataSource.getAll();

      expect(items.length, equals(7));
      expect(items.any((t) => t.type == 'income'), isTrue);
      expect(items.any((t) => t.type == 'expense'), isTrue);
      expect(items.first.id, equals('tx-sample-01'));
    });

    test('2. Chế độ none: getById trả về bản ghi tương ứng', () async {
      final item = await dataSource.getById('tx-sample-01');

      expect(item.id, equals('tx-sample-01'));
      expect(item.title, equals('Nhận lương tháng 10'));
    });

    test('3. Chế độ none: getById không tồn tại -> Ném HttpStatusError(404)',
        () async {
      expect(
        dataSource.getById('tx-not-exist'),
        throwsA(
          isA<HttpStatusError>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('4. Chế độ none: Thêm, sửa, xóa (CRUD) thành công', () async {
      final now = DateTime(2026, 10, 14, 12, 0);
      final newItem = TransactionModel(
        id: 'tx-new-1',
        type: 'expense',
        title: 'Mua cafe sáng',
        amount: 25000,
        category: 'food',
        date: now,
        createdAt: now,
      );

      // Thêm mới
      final added = await dataSource.add(newItem);
      expect(added.id, equals('tx-new-1'));

      final afterAdd = await dataSource.getAll();
      expect(afterAdd.length, equals(8));

      // Cập nhật
      final updatedItem = TransactionModel(
        id: 'tx-new-1',
        type: 'expense',
        title: 'Mua cafe muối',
        amount: 30000,
        category: 'food',
        date: now,
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 5)),
      );
      final updated = await dataSource.update(updatedItem);
      expect(updated.title, equals('Mua cafe muối'));
      expect(updated.amount, equals(30000));

      // Xóa
      await dataSource.delete('tx-new-1');
      final afterDelete = await dataSource.getAll();
      expect(afterDelete.length, equals(7));
      expect(afterDelete.any((t) => t.id == 'tx-new-1'), isFalse);
    });

    test('5. Sửa hoặc xóa ID không tồn tại -> Ném HttpStatusError(404)',
        () async {
      final dummy = TransactionModel(
        id: 'tx-ghost',
        type: 'expense',
        title: 'Ghost',
        amount: 1000,
        category: 'other',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(dataSource.update(dummy), throwsA(isA<HttpStatusError>()));
      expect(dataSource.delete('tx-ghost'), throwsA(isA<HttpStatusError>()));
    });

    group('6. Kiểm tra các chế độ giả lập lỗi (FailureMode)', () {
      test('6.1. FailureMode.network -> Ném SocketException', () async {
        simulator.mode = FailureMode.network;

        expect(
          dataSource.getAll(),
          throwsA(isA<SocketException>()),
        );
      });

      test('6.2. FailureMode.timeout -> Ném TimeoutException', () async {
        simulator.mode = FailureMode.timeout;

        expect(
          dataSource.getAll(),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('6.3. FailureMode.server500 -> Ném HttpStatusError(500)', () async {
        simulator.mode = FailureMode.server500;

        expect(
          dataSource.getAll(),
          throwsA(
            isA<HttpStatusError>()
                .having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      });

      test(
          '6.4. FailureMode.badJson -> Ném ParseException từ TransactionModel.fromJson',
          () async {
        simulator.mode = FailureMode.badJson;

        expect(
          dataSource.getAll(),
          throwsA(isA<ParseException>()),
        );
      });

      test('6.5. Đổi mode có hiệu lực ngay lập tức ở lần gọi tiếp theo',
          () async {
        // Đang ở none -> thành công
        expect(await dataSource.getAll(), isNotEmpty);

        // Đổi sang network -> ném SocketException ngay
        simulator.mode = FailureMode.network;
        await expectLater(dataSource.getAll(), throwsA(isA<SocketException>()));

        // Đổi lại none -> lại thành công ngay
        simulator.mode = FailureMode.none;
        expect(await dataSource.getAll(), isNotEmpty);
      });
    });
  });
}
