import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/core/utils/loggable_mixin.dart';
import 'package:expense_tracker/core/utils/result.dart';
import 'package:expense_tracker/core/utils/timestamp_mixin.dart';
import 'package:expense_tracker/core/utils/validatable_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

// Lớp giả lập phục vụ kiểm thử LoggableMixin
class FakeLoggableService with LoggableMixin {
  final String? customTag;
  FakeLoggableService([this.customTag]);

  @override
  String get logTag => customTag ?? super.logTag;
}

// Lớp giả lập phục vụ kiểm thử ValidatableMixin
class FakeValidatableItem with ValidatableMixin {
  final String title;
  FakeValidatableItem(this.title);

  @override
  List<ValidationException> validate() {
    if (title.isEmpty) {
      return const [
        ValidationException(message: 'Title is required', field: 'title')
      ];
    }
    return const [];
  }
}

// Lớp giả lập phục vụ kiểm thử TimestampMixin
class FakeTimestampEntity with TimestampMixin {
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  FakeTimestampEntity({required this.createdAt, this.updatedAt});
}

void main() {
  group('T-104: Mixins Tests', () {
    group('LoggableMixin', () {
      test('1. logTag mặc định lấy tên runtimeType', () {
        final service = FakeLoggableService();
        expect(service.logTag, equals('FakeLoggableService'));
      });

      test('2. logTag có thể được ghi đè tùy biến', () {
        final service = FakeLoggableService('CustomServiceTag');
        expect(service.logTag, equals('CustomServiceTag'));
      });

      test('3. Gọi logDebug, logInfo, logWarning không sinh lỗi', () {
        final service = FakeLoggableService();
        expect(() => service.logDebug('debug test'), returnsNormally);
        expect(() => service.logInfo('info test'), returnsNormally);
        expect(() => service.logWarning('warning test'), returnsNormally);
      });
    });

    group('ValidatableMixin', () {
      test('4. isValid = true và firstError = null khi không có lỗi', () {
        final validItem = FakeValidatableItem('Valid Title');

        expect(validItem.isValid, isTrue);
        expect(validItem.firstError, isNull);

        final result = validItem.ensureValid();
        expect(result, isA<Success<void>>());
      });

      test('5. isValid = false, firstError trả về exception đầu tiên', () {
        final invalidItem = FakeValidatableItem('');

        expect(invalidItem.isValid, isFalse);
        expect(invalidItem.firstError, isNotNull);
        expect(invalidItem.firstError?.field, equals('title'));

        final result = invalidItem.ensureValid();
        expect(result, isA<Failure<void>>());
        final failure = result as Failure<void>;
        expect(failure.error, isA<ValidationException>());
        expect((failure.error as ValidationException).field, equals('title'));
      });
    });

    group('TimestampMixin', () {
      final t1 = DateTime(2026, 1, 1, 10, 0);
      final t2 = DateTime(2026, 1, 1, 12, 0);
      final t3 = DateTime(2026, 1, 1, 15, 0);

      test('6. lastModified trả về createdAt khi updatedAt là null', () {
        final entity = FakeTimestampEntity(createdAt: t1);
        expect(entity.lastModified, equals(t1));
      });

      test('7. lastModified trả về updatedAt khi updatedAt khác null', () {
        final entity = FakeTimestampEntity(createdAt: t1, updatedAt: t2);
        expect(entity.lastModified, equals(t2));
      });

      test('8. isNewerThan so sánh chính xác giữa hai đối tượng', () {
        final olderEntity = FakeTimestampEntity(createdAt: t1, updatedAt: t2);
        final newerEntity = FakeTimestampEntity(createdAt: t1, updatedAt: t3);

        expect(newerEntity.isNewerThan(olderEntity), isTrue);
        expect(olderEntity.isNewerThan(newerEntity), isFalse);
      });
    });
  });
}
