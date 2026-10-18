import 'package:expense_tracker/core/error_handling/error_handler.dart';
import 'package:expense_tracker/core/error_handling/error_logger.dart';
import 'package:expense_tracker/core/error_handling/error_message_mapper.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/presentation/screens/log_viewer_screen.dart';
import 'package:expense_tracker/presentation/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logger giả lập phục vụ kiểm thử Widget [LogViewerScreen].
class FakeTestErrorLogger implements ErrorLogger {
  List<LogEntry> entries;
  int clearCallCount = 0;
  bool shouldThrow = false;

  FakeTestErrorLogger({List<LogEntry>? initialEntries})
      : entries = initialEntries != null ? List.from(initialEntries) : [];

  @override
  Future<void> log(LogEntry entry) async {
    entries.insert(0, entry);
  }

  @override
  Future<List<LogEntry>> readAll() async {
    if (shouldThrow) {
      throw const FormatException('File log bị lỗi I/O');
    }
    return List.unmodifiable(entries);
  }

  @override
  Future<void> clear() async {
    clearCallCount++;
    entries.clear();
  }
}

void main() {
  final sampleTime = DateTime(2026, 10, 15, 14, 30, 0);

  final sampleInfoEntry = LogEntry(
    timestamp: sampleTime,
    severity: Severity.info,
    code: 'VALIDATION_ERROR',
    errorType: 'ValidationException',
    message: 'Số tiền không hợp lệ',
    source: 'TransactionNotifier',
  );

  final sampleWarningEntry = LogEntry(
    timestamp: sampleTime.add(const Duration(minutes: 1)),
    severity: Severity.warning,
    code: 'NETWORK_ERROR',
    errorType: 'NetworkException',
    message: 'Mất kết nối mạng',
    source: 'FakeRemoteDataSource',
  );

  final sampleErrorEntry = LogEntry(
    timestamp: sampleTime.add(const Duration(minutes: 2)),
    severity: Severity.error,
    code: 'SERVER_ERROR',
    errorType: 'ServerException',
    message: 'Máy chủ phản hồi 500',
    source: 'FakeRemoteDataSource',
    originalError: 'HttpStatusError(500)',
    stackTrace: 'StackTrace: package:expense_tracker/test_trace.dart:42',
  );

  Widget createTestWidget({
    required ErrorLogger logger,
    ErrorHandler? errorHandler,
  }) {
    return MaterialApp(
      home: LogViewerScreen(
        logger: logger,
        errorHandler: errorHandler,
      ),
    );
  }

  group('T-306: LogViewerScreen Widget Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (methodCall) async {
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('1. Hiển thị đúng số entry và thông tin (mới nhất trước)',
        (tester) async {
      final logger = FakeTestErrorLogger(
        initialEntries: [
          sampleErrorEntry,
          sampleWarningEntry,
          sampleInfoEntry,
        ],
      );

      await tester.pumpWidget(createTestWidget(logger: logger));
      await tester.pumpAndSettle();

      // Kiểm tra 3 thẻ Card tương ứng 3 entries
      expect(find.byType(Card), findsNWidgets(3));
      expect(find.text('ServerException'), findsOneWidget);
      expect(find.text('NetworkException'), findsOneWidget);
      expect(find.text('ValidationException'), findsOneWidget);

      // Kiểm tra nhãn Severity và thông điệp
      expect(find.text('ERROR'), findsWidgets);
      expect(find.text('WARN'), findsWidgets);
      expect(find.text('INFO'), findsWidgets);
      expect(find.text('Máy chủ phản hồi 500'), findsOneWidget);
      expect(find.text('Mất kết nối mạng'), findsOneWidget);
    });

    testWidgets(
        '2. Chạm mở rộng xem chi tiết (code, stackTrace, originalError) và nút sao chép',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final logger = FakeTestErrorLogger(
        initialEntries: [sampleErrorEntry],
      );

      await tester.pumpWidget(createTestWidget(logger: logger));
      await tester.pumpAndSettle();

      // Ban đầu nội dung mở rộng chưa xuất hiện trong view tree
      expect(find.text('Sao chép chi tiết'), findsNothing);

      // Chạm vào ExpansionTile để mở rộng
      await tester.tap(find.text('ServerException'));
      await tester.pumpAndSettle();

      // Kiểm tra chi tiết
      expect(find.text('Mã lỗi (Code): SERVER_ERROR'), findsOneWidget);
      expect(find.text('Lỗi gốc: HttpStatusError(500)'), findsOneWidget);
      expect(
        find.text('StackTrace: package:expense_tracker/test_trace.dart:42'),
        findsOneWidget,
      );

      final copyButton = find.text('Sao chép chi tiết');
      expect(copyButton, findsOneWidget);

      // Bấm nút sao chép
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Đã sao chép nội dung log vào clipboard.'),
        findsOneWidget,
      );
    });

    testWidgets('3. Lọc theo Severity bằng FilterChip', (tester) async {
      final logger = FakeTestErrorLogger(
        initialEntries: [
          sampleErrorEntry,
          sampleWarningEntry,
          sampleInfoEntry,
        ],
      );

      await tester.pumpWidget(createTestWidget(logger: logger));
      await tester.pumpAndSettle();

      // Ban đầu hiện cả 3
      expect(find.byType(Card), findsNWidgets(3));

      // Nhấn FilterChip ERROR
      final errorChip = find.widgetWithText(FilterChip, 'ERROR');
      await tester.tap(errorChip);
      await tester.pumpAndSettle();

      // Chỉ còn 1 bản ghi ERROR
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('ServerException'), findsOneWidget);
      expect(find.text('NetworkException'), findsNothing);
      expect(find.text('ValidationException'), findsNothing);

      // Nhấn lại 'Tất cả'
      final allChip = find.widgetWithText(FilterChip, 'Tất cả');
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      // Hiển thị lại cả 3
      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('4. Xóa log có hộp thoại xác nhận và chuyển về trạng thái rỗng',
        (tester) async {
      final logger = FakeTestErrorLogger(
        initialEntries: [sampleErrorEntry],
      );

      await tester.pumpWidget(createTestWidget(logger: logger));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);

      // Bấm nút Xóa trên AppBar
      final deleteIcon = find.byIcon(Icons.delete_sweep_rounded);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Kiểm tra hộp thoại xác nhận
      expect(find.text('Xác nhận xóa nhật ký'), findsOneWidget);
      expect(
        find.text(
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử lỗi đã lưu không? Hành động này không thể hoàn tác.',
        ),
        findsOneWidget,
      );

      // Bấm "Xóa toàn bộ"
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa toàn bộ'));
      await tester.pumpAndSettle();

      expect(logger.clearCallCount, equals(1));
      expect(logger.entries, isEmpty);

      // Chuyển sang giao diện rỗng
      expect(find.text('Chưa có lỗi nào được ghi lại.'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('5. Trạng thái rỗng hiển thị thông điệp khi không có log',
        (tester) async {
      final logger = FakeTestErrorLogger(initialEntries: []);

      await tester.pumpWidget(createTestWidget(logger: logger));
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống hoạt động ổn định'), findsOneWidget);
      expect(find.text('Chưa có lỗi nào được ghi lại.'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('6. Lỗi khi đọc file log đi qua ErrorHandler và hiện ErrorView',
        (tester) async {
      final logger = FakeTestErrorLogger()..shouldThrow = true;
      const errorHandler = ErrorHandler(
        loggers: [],
        messageMapper: ErrorMessageMapper(),
      );

      await tester.pumpWidget(
        createTestWidget(
          logger: logger,
          errorHandler: errorHandler,
        ),
      );
      await tester.pumpAndSettle();

      // ErrorView xuất hiện thay vì crash
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Đã xảy ra sự cố'), findsOneWidget);
    });
  });
}
