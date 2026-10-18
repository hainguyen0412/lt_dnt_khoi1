import 'dart:io';

import 'package:expense_tracker/core/error_handling/file_logger.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-202: FileLogger Unit Tests', () {
    late Directory tempDir;
    late FileLogger fileLogger;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_logger_test_');
      fileLogger = FileLogger(directoryProvider: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    LogEntry createEntry(int id,
        {DateTime? time, Severity severity = Severity.error}) {
      return LogEntry(
        timestamp: time ??
            DateTime.fromMillisecondsSinceEpoch(1700000000000 + id * 1000),
        severity: severity,
        code: 'ERR_$id',
        errorType: 'CustomException',
        message: 'Lỗi số $id',
        source: 'UnitTest',
      );
    }

    test('1. Ghi và đọc lại log thành công', () async {
      final entry = createEntry(1);
      await fileLogger.log(entry);

      final results = await fileLogger.readAll();
      expect(results.length, equals(1));
      expect(results.first.code, equals('ERR_1'));
      expect(results.first.message, equals('Lỗi số 1'));
    });

    test('2. Thứ tự đọc: Luôn trả về bản ghi mới nhất trước (newest first)',
        () async {
      final entry1 = createEntry(1, time: DateTime(2026, 1, 1, 10, 0));
      final entry2 = createEntry(2, time: DateTime(2026, 1, 1, 11, 0));
      final entry3 = createEntry(3, time: DateTime(2026, 1, 1, 12, 0));

      await fileLogger.log(entry1);
      await fileLogger.log(entry2);
      await fileLogger.log(entry3);

      final results = await fileLogger.readAll();
      expect(results.length, equals(3));
      expect(results[0].code, equals('ERR_3'));
      expect(results[1].code, equals('ERR_2'));
      expect(results[2].code, equals('ERR_1'));
    });

    test(
        '3. Giới hạn tối đa 500 bản ghi: Vượt quá 500 thì tự động cắt bỏ bản ghi cũ nhất',
        () async {
      // Ghi 510 bản ghi liên tiếp
      for (int i = 1; i <= 510; i++) {
        await fileLogger.log(createEntry(i));
      }

      final results = await fileLogger.readAll();
      // Chỉ giữ lại đúng 500 bản ghi
      expect(results.length, equals(500));
      // Bản ghi mới nhất là 510
      expect(results.first.code, equals('ERR_510'));
      // Bản ghi cũ nhất còn lại phải là 11 (1..10 đã bị cắt bỏ)
      expect(results.last.code, equals('ERR_11'));
    });

    test(
        '4. Dòng dữ liệu JSON bị hỏng: Tự động bỏ qua và đọc bình thường các dòng hợp lệ',
        () async {
      final entry1 = createEntry(1);
      final entry2 = createEntry(2);

      await fileLogger.log(entry1);

      // Cố tình ghi thêm các dòng hỏng trực tiếp vào file log
      final logFile = File(
          '${tempDir.path}${Platform.pathSeparator}${FileLogger.logFileName}');
      await logFile.writeAsString(
        'DÒNG BỊ HỎNG KHÔNG PHẢI JSON\n'
        '{"corrupt": json incomplete...\n'
        '\n',
        mode: FileMode.append,
        flush: true,
      );

      await fileLogger.log(entry2);

      final results = await fileLogger.readAll();
      expect(results.length, equals(2));
      expect(results[0].code, equals('ERR_2'));
      expect(results[1].code, equals('ERR_1'));
    });

    test(
        '5. clear(): Xóa toàn bộ file nhật ký, readAll() trả về danh sách rỗng',
        () async {
      await fileLogger.log(createEntry(1));
      await fileLogger.log(createEntry(2));

      var results = await fileLogger.readAll();
      expect(results.length, equals(2));

      await fileLogger.clear();

      results = await fileLogger.readAll();
      expect(results, isEmpty);
    });

    test(
        '6. Ghi đồng thời (Concurrent logging): Hàng đợi tuần tự xử lý an toàn không lẫn byte',
        () async {
      // Gửi đồng thời 20 lệnh log không await từng lệnh
      await Future.wait(
        List.generate(20, (index) => fileLogger.log(createEntry(index + 1))),
      );

      final results = await fileLogger.readAll();
      expect(results.length, equals(20));
      // Toàn bộ 20 mã lỗi khác nhau đều hiện diện
      final codes = results.map((e) => e.code).toSet();
      expect(codes.length, equals(20));
    });

    test('7. Không bao giờ ném ngoại lệ ra ngoài khi I/O gặp lỗi', () async {
      // Giả lập provider ném lỗi ngay khi lấy thư mục
      final brokenLogger = FileLogger(
        directoryProvider: () =>
            throw const FileSystemException('Access denied'),
      );

      // Thao tác log, readAll, clear không bao giờ làm crash ứng dụng
      await expectLater(brokenLogger.log(createEntry(1)), completes);
      final entries = await brokenLogger.readAll();
      expect(entries, isEmpty);
      await expectLater(brokenLogger.clear(), completes);
    });
  });
}
