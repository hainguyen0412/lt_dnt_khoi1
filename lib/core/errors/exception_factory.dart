import 'dart:async';
import 'dart:io';

import 'app_exception.dart';
import 'cache_storage_error.dart';
import 'http_status_error.dart';

/// Lớp Factory đảm nhiệm việc chuyển đổi các lỗi thô (raw errors) thành [AppException].
///
/// **Lý do thiết kế Factory Pattern:**
/// Trong hệ thống đa tầng, các nguồn ném lỗi rất đa dạng (SocketException từ mạng,
/// TimeoutException từ async, CacheStorageError từ disk IO, HttpStatusError từ server...).
/// Việc tập trung logic phân loại vào một Factory duy nhất giúp chuẩn hóa toàn bộ lỗi đầu vào,
/// cách ly tầng Domain/UI khỏi sự phụ thuộc vào các exception cụ thể của tầng Data/Driver,
/// và tuân thủ nguyên lý Single Responsibility Principle (SRP).
///
/// **Lưu ý về `TypeError`:**
/// `TypeError` và các lỗi runtime khác được map về [UnknownException] chứ KHÔNG map về
/// [ParseException] ở đây, vì tại tầng factory toàn cục này không thể biết chắc ngữ cảnh phát sinh
/// lỗi (có thể do lỗi lập trình logic chứ không phải parse JSON).
/// Lỗi ép kiểu sai cấu trúc JSON sẽ được `TransactionModel.fromJson` tự bắt trong try-catch
/// nội bộ và bọc tường minh thành [ParseException] tại T-106.
class ExceptionFactory {
  // Lớp chứa hàm tiện ích tĩnh (utility factory), ẩn constructor mặc định.
  const ExceptionFactory._();

  /// Chuyển đổi một đối tượng lỗi bất kỳ [error] và [st] (tùy chọn) thành [AppException] chuẩn.
  ///
  /// Quy tắc xác định `stackTrace`:
  /// - Nếu tham số [st] được truyền vào -> ưu tiên sử dụng [st].
  /// - Nếu không có [st] và [error] là một [Error] trong Dart -> sử dụng `error.stackTrace`.
  /// - Ngược lại -> sử dụng [StackTrace.current].
  ///
  /// Quy tắc ánh xạ phân loại lỗi:
  /// 1. Nếu đã là [AppException] -> trả về nguyên vẹn chính instance đó (identical).
  /// 2. [SocketException], [HttpException], [HandshakeException] -> [NetworkException].
  /// 3. [TimeoutException] (từ `dart:async`) -> [RequestTimeoutException].
  /// 4. [HttpStatusError]: nếu mã 404 -> [NotFoundException]; các mã 4xx/5xx khác -> [ServerException].
  /// 5. [CacheStorageError] -> [CacheException].
  /// 6. [FormatException] -> [ParseException].
  /// 7. [TypeError] và mọi ngoại lệ khác còn lại -> [UnknownException].
  static AppException from(Object error, [StackTrace? st]) {
    // 1. Nếu đã là AppException thì trả về ngay chính nó, giữ nguyên trạng thái ban đầu.
    if (error is AppException) {
      return error;
    }

    // Xác định StackTrace theo thứ tự ưu tiên quy định
    final resolvedStackTrace =
        st ?? (error is Error ? error.stackTrace : null) ?? StackTrace.current;

    // 2. Lỗi mạng và socket đường truyền
    if (error is SocketException) {
      return NetworkException(
        message: 'Network socket failure: ${error.message}',
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }
    if (error is HttpException) {
      return NetworkException(
        message: 'HTTP transport failure: ${error.message}',
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }
    if (error is HandshakeException) {
      return NetworkException(
        message: 'TLS/SSL handshake failure: ${error.message}',
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }

    // 3. Quá thời gian chờ (Timeout)
    if (error is TimeoutException) {
      final detail = error.message ?? 'Operation timed out';
      return RequestTimeoutException(
        message: 'Request timed out: $detail',
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }

    // 4. Lỗi phản hồi HTTP từ server
    if (error is HttpStatusError) {
      if (error.statusCode == 404) {
        return NotFoundException(
          message: error.message ?? 'Requested resource was not found (404)',
          originalError: error,
          stackTrace: resolvedStackTrace,
        );
      }
      return ServerException(
        statusCode: error.statusCode,
        message:
            error.message ?? 'Server responded with status ${error.statusCode}',
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }

    // 5. Lỗi đọc/ghi bộ nhớ đệm
    if (error is CacheStorageError) {
      return CacheException(
        message: error.message,
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }

    // 6. Lỗi định dạng/parse cú pháp
    if (error is FormatException) {
      return ParseException(
        message: 'Data parsing failed: ${error.message}',
        originalError: error,
        stackTrace: resolvedStackTrace,
      );
    }

    // 7. TypeError và mọi lỗi không xác định còn lại
    return UnknownException(
      message: 'Unexpected error occurred: $error',
      originalError: error,
      stackTrace: resolvedStackTrace,
    );
  }
}
