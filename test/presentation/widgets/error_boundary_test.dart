import 'package:expense_tracker/core/error_handling/error_widget_setup.dart';
import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/presentation/widgets/error_boundary.dart';
import 'package:expense_tracker/presentation/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget giả lập cố tình ném lỗi trong phương thức [build] để kiểm thử [ErrorWidget.builder].
class CrashingWidget extends StatelessWidget {
  final String errorMessage;

  const CrashingWidget({
    super.key,
    this.errorMessage = 'Lỗi render cố ý trong phương thức build',
  });

  @override
  Widget build(BuildContext context) {
    throw StateError(errorMessage);
  }
}

void main() {
  late ErrorWidgetBuilder originalErrorWidgetBuilder;

  setUp(() {
    // Lưu lại ErrorWidget.builder gốc trước mỗi test case để tránh ảnh hưởng test khác
    originalErrorWidgetBuilder = ErrorWidget.builder;
  });

  tearDown(() {
    // Khôi phục lại ErrorWidget.builder nguyên bản của Flutter
    ErrorWidget.builder = originalErrorWidgetBuilder;
  });

  group('T-304: ErrorWidget.builder & installErrorWidgetBuilder Tests', () {
    testWidgets(
        '1. Widget ném lỗi trong build() -> ErrorWidget.builder hiển thị ErrorView.compact an toàn',
        (tester) async {
      final prevBuilder = ErrorWidget.builder;
      try {
        // Cài đặt ErrorWidget.builder theo cấu hình T-304
        installErrorWidgetBuilder();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CrashingWidget(),
            ),
          ),
        );

        // Bắt ngoại lệ render từ Flutter Framework
        final exception = tester.takeException();
        expect(exception, isNotNull);
        expect(exception, isA<StateError>());

        // Kiểm tra ErrorView.compact xuất hiện thay vì crash hoặc màn hình đỏ
        expect(find.byType(ErrorView), findsOneWidget);
        expect(
          find.text(
              'Màn hình gặp sự cố khi hiển thị. Hãy quay lại và thử lại.'),
          findsOneWidget,
        );

        // Compact view cho lỗi build không cung cấp nút Thử lại
        expect(find.text('Thử lại'), findsNothing);
      } finally {
        // Khôi phục lại ErrorWidget.builder trước khi test kết thúc để vượt qua _verifyErrorWidgetBuilderUnset
        ErrorWidget.builder = prevBuilder;
      }
    });
  });

  group('T-304: ErrorBoundary Widget Tests', () {
    testWidgets(
        '2. errorSource có lỗi -> hiện ErrorView; bấm Thử lại gọi onRetry; errorSource về null -> hiện lại child',
        (tester) async {
      final errorNotifier = ValueNotifier<UserFacingError?>(null);
      int retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBoundary(
              errorSource: errorNotifier,
              onRetry: () => retryCount++,
              child: const Center(
                child: Text('Nội dung trang chính hợp lệ'),
              ),
            ),
          ),
        ),
      );

      // Ban đầu: không có lỗi -> hiển thị child
      expect(find.text('Nội dung trang chính hợp lệ'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);

      // Giả lập trạng thái State phát hiện lỗi nghiêm trọng qua boundaryError
      errorNotifier.value = const UserFacingError(
        message: 'Kết nối cơ sở dữ liệu bị ngắt đột ngột',
        canRetry: true,
        severity: Severity.error,
      );
      await tester.pump();

      // Lúc này: child bị ẩn, ErrorView xuất hiện với thông điệp
      expect(find.text('Nội dung trang chính hợp lệ'), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('Kết nối cơ sở dữ liệu bị ngắt đột ngột'),
        findsOneWidget,
      );

      // Bấm nút "Thử lại"
      final retryButton = find.widgetWithText(ElevatedButton, 'Thử lại');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();

      expect(retryCount, equals(1));

      // Sau khi thử lại hoặc xóa lỗi: errorSource về null
      errorNotifier.value = null;
      await tester.pump();

      // Giao diện tự động khôi phục lại child ban đầu
      expect(find.text('Nội dung trang chính hợp lệ'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets(
        '3. Khi có truyền onDismiss -> hiển thị nút Bỏ qua và gọi callback khi bấm',
        (tester) async {
      final errorNotifier = ValueNotifier<UserFacingError?>(
        const UserFacingError(
          message: 'Lỗi không xác định cấp màn hình',
          canRetry: true,
          severity: Severity.warning,
        ),
      );
      int dismissCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBoundary(
              errorSource: errorNotifier,
              onRetry: () {},
              onDismiss: () => dismissCount++,
              child: const Text('Nội dung child'),
            ),
          ),
        ),
      );

      // Hiển thị nút Bỏ qua
      final dismissButton = find.widgetWithText(OutlinedButton, 'Bỏ qua');
      expect(dismissButton, findsOneWidget);

      await tester.tap(dismissButton);
      await tester.pump();

      expect(dismissCount, equals(1));
    });

    testWidgets(
        '4. errorSource có canRetry = false -> ErrorView không hiển thị nút Thử lại',
        (tester) async {
      final errorNotifier = ValueNotifier<UserFacingError?>(
        const UserFacingError(
          message: 'Lỗi phiên bản phần mềm không tương thích',
          canRetry: false,
          severity: Severity.critical,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBoundary(
              errorSource: errorNotifier,
              onRetry: () {},
              child: const Text('Nội dung child'),
            ),
          ),
        ),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('Lỗi phiên bản phần mềm không tương thích'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsNothing);
    });
  });
}
