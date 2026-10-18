import 'package:expense_tracker/core/error_handling/error_message_mapper.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-203: ErrorMessageMapper Unit Tests', () {
    const mapper = ErrorMessageMapper();

    test('1. Kiểm tra const constructor và instance method', () {
      const mapper1 = ErrorMessageMapper();
      const mapper2 = ErrorMessageMapper();
      expect(identical(mapper1, mapper2), isTrue);
    });

    test('2. NetworkException -> Thông báo mất mạng tiếng Việt', () {
      const ex = NetworkException(message: 'Failed to connect to host');
      final msg = mapper.messageFor(ex);

      expect(
          msg, equals('Không có kết nối mạng. Vui lòng kiểm tra và thử lại.'));
      expect(msg, isNot(contains('NetworkException')));
      expect(msg, isNot(contains('SocketException')));
    });

    test('3. RequestTimeoutException -> Thông báo timeout phản hồi quá chậm',
        () {
      const ex =
          RequestTimeoutException(message: 'Request timed out after 5000ms');
      final msg = mapper.messageFor(ex);

      expect(msg, equals('Máy chủ phản hồi quá chậm. Vui lòng thử lại.'));
      expect(msg, isNot(contains('TimeoutException')));
    });

    test('4. ServerException 5xx -> Thông báo máy chủ gặp sự cố', () {
      final ex500 =
          ServerException(statusCode: 500, message: 'Internal Server Error');
      final ex503 =
          ServerException(statusCode: 503, message: 'Service Unavailable');

      expect(
        mapper.messageFor(ex500),
        equals('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
      );
      expect(
        mapper.messageFor(ex503),
        equals('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
      );
    });

    test('5. ServerException 4xx -> Thông báo yêu cầu không hợp lệ', () {
      final ex400 = ServerException(statusCode: 400, message: 'Bad Request');
      final ex403 = ServerException(statusCode: 403, message: 'Forbidden');

      expect(mapper.messageFor(ex400), equals('Yêu cầu không hợp lệ.'));
      expect(mapper.messageFor(ex403), equals('Yêu cầu không hợp lệ.'));
    });

    test('6. ParseException -> Thông báo dữ liệu không đúng định dạng', () {
      const ex = ParseException(message: 'Field "amount" is missing');
      final msg = mapper.messageFor(ex);

      expect(msg, equals('Dữ liệu nhận về không đúng định dạng.'));
      expect(msg, isNot(contains('ParseException')));
    });

    test('7. CacheException -> Thông báo không đọc được dữ liệu trên máy', () {
      const ex = CacheException(message: 'Disk read failed');
      final msg = mapper.messageFor(ex);

      expect(msg, equals('Không đọc được dữ liệu lưu trên máy.'));
      expect(msg, isNot(contains('CacheException')));
    });

    test(
        '8. ValidationException -> Giữ nguyên message nghiệp vụ đã chứa field cụ thể',
        () {
      const exTitle = ValidationException(
        field: 'title',
        message: 'Tiêu đề không được để trống.',
      );
      const exAmount = ValidationException(
        field: 'amount',
        message: 'Số tiền giao dịch phải lớn hơn 0.',
      );

      expect(
          mapper.messageFor(exTitle), equals('Tiêu đề không được để trống.'));
      expect(mapper.messageFor(exAmount),
          equals('Số tiền giao dịch phải lớn hơn 0.'));
    });

    test('9. NotFoundException -> Thông báo không tìm thấy dữ liệu yêu cầu',
        () {
      const ex = NotFoundException(message: 'Transaction not found');
      final msg = mapper.messageFor(ex);

      expect(msg, equals('Không tìm thấy dữ liệu yêu cầu.'));
      expect(msg, isNot(contains('NotFoundException')));
    });

    test('10. UnknownException -> Thông báo lỗi không xác định', () {
      const ex = UnknownException(message: 'Uncaught TypeError');
      final msg = mapper.messageFor(ex);

      expect(msg, equals('Đã xảy ra lỗi không xác định.'));
      expect(msg, isNot(contains('UnknownException')));
      expect(msg, isNot(contains('TypeError')));
    });

    test('11. Toàn bộ các thông điệp trả về đều khác nhau giữa các nhóm lỗi',
        () {
      final messages = {
        mapper.messageFor(const NetworkException(message: 'net')),
        mapper.messageFor(const RequestTimeoutException(message: 'timeout')),
        mapper.messageFor(ServerException(statusCode: 500, message: '500')),
        mapper.messageFor(ServerException(statusCode: 400, message: '400')),
        mapper.messageFor(const ParseException(message: 'parse')),
        mapper.messageFor(const CacheException(message: 'cache')),
        mapper.messageFor(
            const ValidationException(field: 'id', message: 'Mã không đúng')),
        mapper.messageFor(const NotFoundException(message: 'not found')),
        mapper.messageFor(const UnknownException(message: 'unknown')),
      };

      // 9 loại lỗi tạo ra 9 thông điệp phân biệt hoàn toàn
      expect(messages.length, equals(9));
    });
  });
}
