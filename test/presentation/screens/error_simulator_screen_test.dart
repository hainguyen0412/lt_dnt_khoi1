import 'package:expense_tracker/core/error_handling/error_handler.dart';
import 'package:expense_tracker/core/error_handling/error_logger.dart';
import 'package:expense_tracker/core/error_handling/error_message_mapper.dart';
import 'package:expense_tracker/core/error_handling/error_widget_setup.dart';
import 'package:expense_tracker/core/error_handling/log_entry.dart';
import 'package:expense_tracker/core/error_handling/user_facing_error.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/simulation/failure_mode.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_draft.dart';
import 'package:expense_tracker/presentation/screens/error_simulator_screen.dart';
import 'package:expense_tracker/presentation/screens/log_viewer_screen.dart';
import 'package:expense_tracker/presentation/state/transaction_notifier.dart';
import 'package:expense_tracker/presentation/state/transaction_state.dart';
import 'package:expense_tracker/presentation/widgets/error_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Logger giả lập phục vụ kiểm thử điều hướng sang [LogViewerScreen].
class FakeTestErrorLogger implements ErrorLogger {
  final List<LogEntry> entries = [];

  @override
  Future<void> log(LogEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<List<LogEntry>> readAll() async {
    return List.unmodifiable(entries);
  }

  @override
  Future<void> clear() async {
    entries.clear();
  }
}

/// Notifier giả lập phục vụ kiểm thử [ErrorSimulatorScreen].
class FakeSimulatorTransactionNotifier extends ChangeNotifier
    implements TransactionNotifier {
  TransactionListState _fakeState;
  final Map<String, String> _fakeFieldErrors = {};
  int loadCallCount = 0;
  TransactionDraft? lastAddedDraft;

  final ValueNotifier<UserFacingError?> _fakeBoundaryError =
      ValueNotifier<UserFacingError?>(null);

  FakeSimulatorTransactionNotifier({
    TransactionListState initialState = const TransactionListInitial(),
  }) : _fakeState = initialState;

  void emitState(TransactionListState state) {
    _fakeState = state;
    notifyListeners();
  }

  @override
  TransactionListState get listState => _fakeState;

  @override
  Map<String, String> get fieldErrors => _fakeFieldErrors;

  @override
  bool get isSubmitting => false;

  @override
  UserFacingError? get actionError => null;

  @override
  ValueListenable<UserFacingError?> get boundaryError => _fakeBoundaryError;

  @override
  Future<void> load() async {
    loadCallCount++;
  }

  @override
  Future<bool> add(TransactionDraft draft) async {
    lastAddedDraft = draft;
    if (draft.amount.amount <= 0) {
      _fakeFieldErrors['amount'] = 'Số tiền giao dịch phải lớn hơn 0.';
      notifyListeners();
      return false;
    }
    return true;
  }

  @override
  Future<bool> update(Transaction transaction) async => true;

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<void> retryLast() async {}

  @override
  void clearActionError() {}

  @override
  void clearFieldErrors([String? field]) {
    _fakeFieldErrors.clear();
    notifyListeners();
  }

  @override
  void reportBoundaryError(UserFacingError error) {
    _fakeBoundaryError.value = error;
  }

  @override
  void clearBoundaryError() {
    _fakeBoundaryError.value = null;
  }
}

void main() {
  late ErrorWidgetBuilder originalErrorWidgetBuilder;

  setUp(() {
    originalErrorWidgetBuilder = ErrorWidget.builder;
  });

  tearDown(() {
    ErrorWidget.builder = originalErrorWidgetBuilder;
  });

  Widget createTestWidget({
    required FailureSimulator simulator,
    required TransactionNotifier notifier,
    ErrorLogger? logger,
    ErrorHandler? errorHandler,
    VoidCallback? onTriggerAsyncError,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FailureSimulator>.value(value: simulator),
        ChangeNotifierProvider<TransactionNotifier>.value(value: notifier),
        Provider<ErrorLogger>.value(value: logger ?? FakeTestErrorLogger()),
        Provider<ErrorHandler>.value(
          value: errorHandler ??
              const ErrorHandler(
                loggers: [],
                messageMapper: ErrorMessageMapper(),
              ),
        ),
      ],
      child: MaterialApp(
        home: ErrorSimulatorScreen(
          simulator: simulator,
          notifier: notifier,
          onTriggerAsyncError: onTriggerAsyncError,
        ),
      ),
    );
  }

  group('T-305: ErrorSimulatorScreen Widget Tests', () {
    testWidgets('1. Chọn chế độ -> FailureSimulator.mode cập nhật ngay lập tức',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final simulator = FailureSimulator(FailureMode.none);
      final notifier = FakeSimulatorTransactionNotifier();

      await tester.pumpWidget(
        createTestWidget(simulator: simulator, notifier: notifier),
      );
      await tester.pumpAndSettle();

      expect(simulator.mode, equals(FailureMode.none));

      // Bấm chip Mất mạng
      final networkChip = find.widgetWithText(ChoiceChip, 'Mất mạng (Socket)');
      await tester.ensureVisible(networkChip);
      await tester.tap(networkChip);
      await tester.pump();

      expect(simulator.mode, equals(FailureMode.network));

      // Bấm chip Lỗi máy chủ
      final serverChip = find.widgetWithText(ChoiceChip, 'Lỗi máy chủ (500)');
      await tester.ensureVisible(serverChip);
      await tester.tap(serverChip);
      await tester.pump();

      expect(simulator.mode, equals(FailureMode.server500));
    });

    testWidgets(
        '2. Bấm Tải lại ở chế độ network -> gọi notifier.load và hiện thông báo lỗi tiếng Việt',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final simulator = FailureSimulator(FailureMode.network);
      final notifier = FakeSimulatorTransactionNotifier(
        initialState: const TransactionListError(
          error: UserFacingError(
            message:
                'Mất kết nối mạng. Vui lòng kiểm tra đường truyền Wi-Fi/4G và thử lại.',
            canRetry: true,
            severity: Severity.warning,
          ),
        ),
      );

      await tester.pumpWidget(
        createTestWidget(simulator: simulator, notifier: notifier),
      );
      await tester.pumpAndSettle();

      final reloadButton = find.text('Tải lại danh sách (load)');
      await tester.ensureVisible(reloadButton);
      await tester.tap(reloadButton);
      await tester.pump();

      expect(notifier.loadCallCount, equals(1));
      expect(
        find.text(
          'Lỗi hiển thị: Mất kết nối mạng. Vui lòng kiểm tra đường truyền Wi-Fi/4G và thử lại. (canRetry: true)',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        '3. Nút Gây lỗi trong build -> kích hoạt ErrorWidget.builder và khôi phục được',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prevBuilder = ErrorWidget.builder;
      try {
        installErrorWidgetBuilder();

        final simulator = FailureSimulator();
        final notifier = FakeSimulatorTransactionNotifier();

        await tester.pumpWidget(
          createTestWidget(simulator: simulator, notifier: notifier),
        );
        await tester.pumpAndSettle();

        expect(
            find.text('Widget con đang render bình thường.'), findsOneWidget);

        // Bấm nút kích hoạt lỗi build
        final triggerBuildBtn = find.text('Kích hoạt lỗi render trong build');
        await tester.ensureVisible(triggerBuildBtn);
        await tester.tap(triggerBuildBtn);
        await tester.pump();

        // Bắt lỗi render ném từ _CrashingSampleWidget
        final exception = tester.takeException();
        expect(exception, isNotNull);

        // ErrorView.compact thay thế vị trí widget con bị lỗi
        expect(find.byType(ErrorView), findsOneWidget);
        expect(
          find.text(
              'Màn hình gặp sự cố khi hiển thị. Hãy quay lại và thử lại.'),
          findsOneWidget,
        );

        // Bấm nút khôi phục
        final restoreBtn = find.text('Khôi phục build bình thường');
        await tester.ensureVisible(restoreBtn);
        await tester.tap(restoreBtn);
        await tester.pump();

        expect(
            find.text('Widget con đang render bình thường.'), findsOneWidget);
      } finally {
        ErrorWidget.builder = prevBuilder;
      }
    });

    testWidgets(
        '4. Nút Gây lỗi validation -> gửi số tiền âm và hiển thị lỗi từ fieldErrors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final simulator = FailureSimulator();
      final notifier = FakeSimulatorTransactionNotifier();

      await tester.pumpWidget(
        createTestWidget(simulator: simulator, notifier: notifier),
      );
      await tester.pumpAndSettle();

      final triggerValBtn = find.text('Gửi giao dịch số tiền âm');
      await tester.ensureVisible(triggerValBtn);
      await tester.tap(triggerValBtn);
      await tester.pump();

      expect(notifier.lastAddedDraft, isNotNull);
      expect(notifier.lastAddedDraft!.amount.amount, equals(-50000));
      expect(
        find.text('fieldErrors["amount"]: Số tiền giao dịch phải lớn hơn 0.'),
        findsOneWidget,
      );
    });

    testWidgets('5. Nút Gây lỗi async -> hiển thị SnackBar hướng dẫn xem log',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool asyncTriggered = false;
      final simulator = FailureSimulator();
      final notifier = FakeSimulatorTransactionNotifier();

      await tester.pumpWidget(
        createTestWidget(
          simulator: simulator,
          notifier: notifier,
          onTriggerAsyncError: () => asyncTriggered = true,
        ),
      );
      await tester.pumpAndSettle();

      final asyncBtn = find.text('Kích hoạt lỗi unhandled async');
      await tester.ensureVisible(asyncBtn);
      await tester.tap(asyncBtn);
      await tester.pump();

      expect(asyncTriggered, isTrue);
      expect(
        find.text(
          'Đã kích hoạt lỗi async. Kiểm tra console hoặc Log Viewer để thấy bản ghi!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('6. Nút AppBar -> điều hướng tới LogViewerScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final simulator = FailureSimulator();
      final notifier = FakeSimulatorTransactionNotifier();

      await tester.pumpWidget(
        createTestWidget(simulator: simulator, notifier: notifier),
      );
      await tester.pumpAndSettle();

      final historyBtn = find.byIcon(Icons.history_edu_outlined);
      await tester.tap(historyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LogViewerScreen), findsOneWidget);
    });
  });
}
