import 'dart:developer' as developer;

import '../errors/app_exception.dart';
import 'error_logger.dart';
import 'error_message_mapper.dart';
import 'log_entry.dart';
import 'user_facing_error.dart';

/// Bộ xử lý ngoại lệ tập trung (Centralized Error Handling Pipeline).
///
/// **Lý do thiết kế Pipeline Pattern (R11):**
/// Thay vì để từng màn hình UI hay từng hàm xử lý lỗi theo cách chắp vá, [ErrorHandler]
/// tập trung toàn bộ quy trình xử lý ngoại lệ vào một pipeline duy nhất gồm 5 bước tuần tự:
/// 1. Chuẩn hóa ([_normalize]): Chuyển đổi mọi lỗi thô thành [AppException].
/// 2. Phân loại ([_classify]): Xác định [Severity] và nâng cấp nếu là lỗi toàn cục lọt lưới.
/// 3. Ghi log ([_log]): Tạo [LogEntry] và gửi tới tất cả các [ErrorLogger] đã đăng ký.
/// 4. Quyết định thử lại ([_decideRetry]): Đánh giá xem lỗi có thể tự phục hồi khi bấm "Thử lại" hay không.
/// 5. Chuyển ngữ ([_toUserMessage]): Tạo thông điệp tiếng Việt thân thiện bằng [ErrorMessageMapper].
///
/// **Cam kết hợp đồng:**
/// Phương thức [handle] **KHÔNG BAO GIỜ** ném ngoại lệ ra ngoài. Nếu chính pipeline
/// gặp sự cố, nó sẽ rơi về chế độ an toàn (fallback) và trả về [UserFacingError] mức `critical`.
class ErrorHandler {
  final List<ErrorLogger> _loggers;
  final ErrorMessageMapper _messageMapper;

  /// Khởi tạo [ErrorHandler] với danh sách các [loggers] và [messageMapper] thông qua Constructor Injection.
  const ErrorHandler({
    required List<ErrorLogger> loggers,
    required ErrorMessageMapper messageMapper,
  })  : _loggers = loggers,
        _messageMapper = messageMapper;

  /// Điểm vào duy nhất tiếp nhận mọi ngoại lệ phát sinh trong hệ thống.
  ///
  /// Thực thi tuần tự pipeline 5 bước và trả về [UserFacingError] an toàn cho tầng UI.
  Future<UserFacingError> handle(
    Object error,
    StackTrace st, {
    String? source,
  }) async {
    try {
      // Bước 1: Chuẩn hóa mọi lỗi thô thành cây ngoại lệ AppException
      final AppException appEx = _normalize(error, st);

      // Bước 2: Phân loại mức độ nghiêm trọng (nâng cấp nếu là lỗi toàn cục lọt lưới)
      final Severity severity = _classify(appEx, source);

      // Bước 3: Ghi nhật ký lỗi có cấu trúc tới toàn bộ danh sách logger
      await _log(appEx, severity, st, source);

      // Bước 4: Đánh giá khả năng cho phép người dùng bấm nút Thử lại (canRetry)
      final bool canRetry = _decideRetry(appEx);

      // Bước 5: Chuyển dịch ngoại lệ kỹ thuật sang thông điệp tiếng Việt thân thiện
      final String message = _toUserMessage(appEx);

      return UserFacingError(
        message: message,
        canRetry: canRetry,
        severity: severity,
      );
    } catch (pipelineError, pipelineSt) {
      // PHÒNG THỦ NGOẠI LỆ TUYỆT ĐỐI (Fallback Safety Net):
      // Nếu chính các bước bên trong pipeline xử lý lỗi gặp sự cố lập trình bất ngờ,
      // ErrorHandler tuyệt đối KHÔNG ĐƯỢC làm sập ứng dụng. Ta ghi nhận sự cố khẩn cấp
      // ra console và trả về UserFacingError fallback mức critical.
      developer.log(
        'ErrorHandler pipeline gặp sự cố bất ngờ: $pipelineError',
        name: 'ErrorHandler',
        error: pipelineError,
        stackTrace: pipelineSt,
      );
      return const UserFacingError(
        message: 'Đã xảy ra lỗi không xác định.',
        canRetry: false,
        severity: Severity.critical,
      );
    }
  }

  /// Bước 1: Chuẩn hóa đối tượng lỗi bất kỳ thành [AppException].
  ///
  /// Nếu bản thân [error] đã là một [AppException] thì giữ nguyên vẹn instance đó.
  AppException _normalize(Object error, StackTrace st) {
    return AppException.from(error, st);
  }

  /// Bước 2: Phân loại mức độ nghiêm trọng của ngoại lệ.
  ///
  /// - Sử dụng mức [Severity] gốc đã được quy định chuẩn hóa trong [AppException].
  /// - **Quy tắc biên an toàn (Safety Net Elevation):** Nếu `source == 'global'` (lỗi lọt
  ///   qua mọi tầng bắt lỗi và rơi vào error boundary cấp cao nhất), mức độ nghiêm trọng
  ///   sẽ được nâng tối thiểu lên [Severity.error].
  Severity _classify(AppException exception, String? source) {
    final Severity baseSeverity = exception.severity;
    if (source == 'global') {
      return switch (baseSeverity) {
        Severity.info || Severity.warning => Severity.error,
        Severity.error => Severity.error,
        Severity.critical => Severity.critical,
      };
    }
    return baseSeverity;
  }

  /// Bước 3: Ghi nhật ký lỗi tới tất cả các [ErrorLogger] đã đăng ký.
  ///
  /// **Nguyên tắc cô lập lỗi (Fault Isolation):**
  /// Mỗi lời gọi `logger.log(entry)` được bảo vệ độc lập bằng try-catch.
  /// Nếu một logger gặp sự cố (ví dụ ghi tệp thất bại), nó tuyệt đối không được
  /// làm gián đoạn hoặc ngăn cản các logger còn lại ghi nhận sự cố.
  Future<void> _log(
    AppException exception,
    Severity severity,
    StackTrace st,
    String? source,
  ) async {
    final LogEntry entry = LogEntry(
      timestamp: DateTime.now(),
      severity: severity,
      code: exception.code,
      errorType: exception.runtimeType.toString(),
      message: exception.message,
      source: source,
      stackTrace: st.toString(),
      originalError: exception.originalError?.toString(),
    );

    for (final ErrorLogger logger in _loggers) {
      try {
        await logger.log(entry);
      } catch (loggerError, loggerSt) {
        developer.log(
          'ErrorHandler: Logger ${logger.runtimeType} ném ngoại lệ khi ghi log: $loggerError',
          name: 'ErrorHandler',
          error: loggerError,
          stackTrace: loggerSt,
        );
      }
    }
  }

  /// Bước 4: Đưa ra quyết định cho phép người dùng thử lại thao tác ([canRetry]).
  ///
  /// - **Nhóm cho phép thử lại (`true`):**
  ///   - [NetworkException]: Mất kết nối mạng tạm thời; khi người dùng bật lại wifi/4G thì thao tác sẽ thành công.
  ///   - [RequestTimeoutException]: Máy chủ hoặc mạng bị nghẽn tạm thời; gửi lại yêu cầu có thể hoàn thành.
  ///   - [ServerException] mã 5xx: Máy chủ nội bộ bị quá tải hoặc khởi động lại tạm thời.
  ///   - [UnknownException]: Lỗi bất định hoặc race condition runtime; thử lại là cơ hội để hệ thống tự phục hồi.
  ///
  /// - **Nhóm không cho phép thử lại (`false`):**
  ///   - [ValidationException]: Dữ liệu người dùng nhập sai quy tắc nghiệp vụ; nếu không sửa form mà bấm lại thì vẫn sai 100%.
  ///   - [NotFoundException]: Tài nguyên không tồn tại trên máy chủ; bấm thử lại vô ích.
  ///   - [ServerException] mã 4xx: Phía client gửi sai tham số hoặc bị từ chối quyền truy cập; thử lại không thể giải quyết.
  ///   - [ParseException]: Dữ liệu trả về sai cấu trúc định dạng JSON; đây là lỗi lập trình schema, thử lại vẫn hỏng.
  ///   - [CacheException]: Lỗi truy xuất phần cứng/bộ nhớ đệm trên thiết bị; cần khắc phục bộ nhớ chứ không phải thử lại.
  bool _decideRetry(AppException exception) {
    return switch (exception) {
      NetworkException() => true,
      RequestTimeoutException() => true,
      ServerException(:final isServerError) => isServerError,
      UnknownException() => true,
      ValidationException() => false,
      NotFoundException() => false,
      ParseException() => false,
      CacheException() => false,
    };
  }

  /// Bước 5: Chuyển dịch ngoại lệ kỹ thuật thành câu thông điệp tiếng Việt thân thiện.
  String _toUserMessage(AppException exception) {
    return _messageMapper.messageFor(exception);
  }
}
