import '../errors/app_exception.dart';

/// Đại diện cho một bản ghi nhật ký lỗi có cấu trúc (Structured Log Entry).
///
/// **Lý do thiết kế:**
/// Thay vì chỉ ghi chuỗi văn bản tự do khó phân tích, [LogEntry] chuẩn hóa mọi
/// thông tin cần thiết của một lỗi phát sinh trong hệ thống: thời điểm, độ nghiêm
/// trọng, mã lỗi, loại lỗi, thông điệp, nguồn phát sinh và stack trace.
/// Hỗ trợ [toJson] và [fromJson] để lưu trữ tuần tự dạng JSON Lines.
class LogEntry {
  /// Thời điểm xảy ra lỗi.
  final DateTime timestamp;

  /// Mức độ nghiêm trọng của lỗi ([Severity.info], [Severity.warning], [Severity.error], [Severity.critical]).
  final Severity severity;

  /// Mã định danh lỗi (ví dụ: 'NETWORK_ERROR', 'SERVER_ERROR').
  final String code;

  /// Tên lớp runtime của ngoại lệ (ví dụ: 'NetworkException', 'SocketException').
  final String errorType;

  /// Thông điệp kỹ thuật tóm tắt lỗi.
  final String message;

  /// Nguồn phát sinh lỗi (tên class, module hoặc usecase, ví dụ: 'FakeRemoteDataSource').
  final String? source;

  /// Chuỗi vết ngăn xếp ngăn dòng lỗi (nếu có).
  final String? stackTrace;

  /// Chuỗi mô tả lỗi gốc ban đầu (nếu có).
  final String? originalError;

  /// Khởi tạo một bản ghi log bất biến.
  const LogEntry({
    required this.timestamp,
    required this.severity,
    required this.code,
    required this.errorType,
    required this.message,
    this.source,
    this.stackTrace,
    this.originalError,
  });

  /// Chuyển đổi [LogEntry] sang định dạng `Map<String, dynamic>` để serialize JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'code': code,
      'errorType': errorType,
      'message': message,
      if (source != null) 'source': source,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (originalError != null) 'originalError': originalError,
    };
  }

  /// Khởi tạo một [LogEntry] từ `Map<String, dynamic>` (Factory Constructor - R2).
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      severity: Severity.values.byName(json['severity'] as String),
      code: json['code'] as String,
      errorType: json['errorType'] as String,
      message: json['message'] as String,
      source: json['source'] as String?,
      stackTrace: json['stackTrace'] as String?,
      originalError: json['originalError'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogEntry &&
        other.timestamp == timestamp &&
        other.severity == severity &&
        other.code == code &&
        other.errorType == errorType &&
        other.message == message &&
        other.source == source &&
        other.stackTrace == stackTrace &&
        other.originalError == originalError;
  }

  @override
  int get hashCode => Object.hash(
        timestamp,
        severity,
        code,
        errorType,
        message,
        source,
        stackTrace,
        originalError,
      );

  @override
  String toString() {
    return 'LogEntry(time: $timestamp, [${severity.name.toUpperCase()}] $errorType($code): $message, source: $source)';
  }
}
