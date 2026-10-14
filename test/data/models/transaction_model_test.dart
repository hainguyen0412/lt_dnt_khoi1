import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/models/transaction_model.dart';
import 'package:expense_tracker/domain/entities/category.dart';
import 'package:expense_tracker/domain/entities/money.dart';
import 'package:expense_tracker/domain/entities/transaction.dart';
import 'package:expense_tracker/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-106: TransactionModel Tests', () {
    final fixedDate = DateTime.parse('2026-10-14T10:00:00.000Z');
    final fixedCreatedAt = DateTime.parse('2026-10-14T10:05:00.000Z');
    final fixedUpdatedAt = DateTime.parse('2026-10-14T11:00:00.000Z');

    final validFullJson = <String, dynamic>{
      'id': 'tx-100',
      'type': 'expense',
      'title': 'Tiền cơm trưa',
      'amount': 35000,
      'category': 'food',
      'date': fixedDate.toIso8601String(),
      'note': 'Cơm gà xối mỡ',
      'createdAt': fixedCreatedAt.toIso8601String(),
      'updatedAt': fixedUpdatedAt.toIso8601String(),
    };

    final validMinimalJson = <String, dynamic>{
      'id': 'tx-101',
      'type': 'income',
      'title': 'Lương tháng',
      'amount': 15000000,
      'category': 'salary',
      'date': fixedDate.toIso8601String(),
      'note': null,
      'createdAt': fixedCreatedAt.toIso8601String(),
      'updatedAt': null,
    };

    test('1. fromJson giải mã thành công JSON đầy đủ các trường', () {
      final model = TransactionModel.fromJson(validFullJson);

      expect(model.id, equals('tx-100'));
      expect(model.type, equals('expense'));
      expect(model.title, equals('Tiền cơm trưa'));
      expect(model.amount, equals(35000));
      expect(model.category, equals('food'));
      expect(model.date, equals(fixedDate));
      expect(model.note, equals('Cơm gà xối mỡ'));
      expect(model.createdAt, equals(fixedCreatedAt));
      expect(model.updatedAt, equals(fixedUpdatedAt));
    });

    test('2. fromJson giải mã thành công JSON không có note và updatedAt', () {
      final model = TransactionModel.fromJson(validMinimalJson);

      expect(model.id, equals('tx-101'));
      expect(model.type, equals('income'));
      expect(model.note, isNull);
      expect(model.updatedAt, isNull);
    });

    test(
        '3. Round-trip: entity -> fromEntity -> toJson -> fromJson -> toEntity bảo toàn nguyên vẹn',
        () {
      final originalEntity = Transaction(
        id: 'tx-roundtrip',
        type: TransactionType.expense,
        title: 'Mua sách giáo trình',
        amount: const Money(120000),
        category: Category.entertainment,
        date: fixedDate,
        note: 'Sách Flutter OOP',
        createdAt: fixedCreatedAt,
        updatedAt: fixedUpdatedAt,
      );

      final modelFromEntity = TransactionModel.fromEntity(originalEntity);
      final jsonMap = modelFromEntity.toJson();
      final modelFromJson = TransactionModel.fromJson(jsonMap);
      final convertedEntity = modelFromJson.toEntity();

      expect(convertedEntity, equals(originalEntity));
      expect(convertedEntity.id, equals(originalEntity.id));
      expect(convertedEntity.type, equals(originalEntity.type));
      expect(convertedEntity.amount, equals(originalEntity.amount));
      expect(convertedEntity.category, equals(originalEntity.category));
    });

    test(
        '4. Model không kiểm tra nghiệp vụ: cho phép số tiền âm hoặc 0 nếu đúng kiểu int',
        () {
      final jsonNegativeAmount = Map<String, dynamic>.from(validFullJson)
        ..['amount'] = -50000;

      final model = TransactionModel.fromJson(jsonNegativeAmount);
      expect(model.amount, equals(-50000));
    });

    test('5. TimestampMixin trên TransactionModel hoạt động chuẩn xác (R3)',
        () {
      final modelWithUpdate = TransactionModel.fromJson(validFullJson);
      final modelWithoutUpdate = TransactionModel.fromJson(validMinimalJson);

      expect(modelWithUpdate.lastModified, equals(fixedUpdatedAt));
      expect(modelWithoutUpdate.lastModified, equals(fixedCreatedAt));
      expect(modelWithUpdate.isNewerThan(modelWithoutUpdate), isTrue);
    });

    group(
        '6. Bảng kiểm thử các JSON hỏng: Bắt buộc ném ParseException kèm tên trường',
        () {
      void expectParseException(Object? badJson, String expectedFieldName) {
        expect(
          () => TransactionModel.fromJson(badJson),
          throwsA(
            isA<ParseException>().having(
              (e) => e.message.toLowerCase(),
              'message chứa tên trường',
              contains(expectedFieldName.toLowerCase()),
            ),
          ),
        );
      }

      test('6.1. Dữ liệu JSON không phải Map (null, String, List)', () {
        expectParseException(null, 'Map');
        expectParseException('not a map', 'Map');
        expectParseException([1, 2, 3], 'Map');
      });

      test('6.2. Thiếu hoặc sai trường id', () {
        final missingId = Map<String, dynamic>.from(validFullJson)
          ..remove('id');
        expectParseException(missingId, 'id');

        final wrongTypeId = Map<String, dynamic>.from(validFullJson)
          ..['id'] = 12345;
        expectParseException(wrongTypeId, 'id');
      });

      test('6.3. Thiếu hoặc sai trường type', () {
        final missingType = Map<String, dynamic>.from(validFullJson)
          ..remove('type');
        expectParseException(missingType, 'type');

        final wrongTypeValue = Map<String, dynamic>.from(validFullJson)
          ..['type'] = 'loan';
        expectParseException(wrongTypeValue, 'type');
      });

      test('6.4. Thiếu hoặc sai trường title', () {
        final missingTitle = Map<String, dynamic>.from(validFullJson)
          ..remove('title');
        expectParseException(missingTitle, 'title');

        final wrongTypeTitle = Map<String, dynamic>.from(validFullJson)
          ..['title'] = 999;
        expectParseException(wrongTypeTitle, 'title');
      });

      test('6.5. Thiếu hoặc sai trường amount (String, double thập phân, null)',
          () {
        final missingAmount = Map<String, dynamic>.from(validFullJson)
          ..remove('amount');
        expectParseException(missingAmount, 'amount');

        final stringAmount = Map<String, dynamic>.from(validFullJson)
          ..['amount'] = '50000';
        expectParseException(stringAmount, 'amount');

        final floatAmount = Map<String, dynamic>.from(validFullJson)
          ..['amount'] = 50000.75;
        expectParseException(floatAmount, 'amount');
      });

      test('6.6. Thiếu hoặc sai trường category', () {
        final missingCategory = Map<String, dynamic>.from(validFullJson)
          ..remove('category');
        expectParseException(missingCategory, 'category');

        final unknownCategory = Map<String, dynamic>.from(validFullJson)
          ..['category'] = 'gambling';
        expectParseException(unknownCategory, 'category');
      });

      test('6.7. Thiếu hoặc sai trường date (không parse được ISO-8601)', () {
        final missingDate = Map<String, dynamic>.from(validFullJson)
          ..remove('date');
        expectParseException(missingDate, 'date');

        final invalidDateStr = Map<String, dynamic>.from(validFullJson)
          ..['date'] = 'invalid-date-format';
        expectParseException(invalidDateStr, 'date');
      });

      test('6.8. Thiếu hoặc sai trường createdAt', () {
        final missingCreatedAt = Map<String, dynamic>.from(validFullJson)
          ..remove('createdAt');
        expectParseException(missingCreatedAt, 'createdAt');

        final invalidCreatedAt = Map<String, dynamic>.from(validFullJson)
          ..['createdAt'] = 'not-a-timestamp';
        expectParseException(invalidCreatedAt, 'createdAt');
      });

      test('6.9. Sai trường updatedAt', () {
        final invalidUpdatedAt = Map<String, dynamic>.from(validFullJson)
          ..['updatedAt'] = 'bad-timestamp';
        expectParseException(invalidUpdatedAt, 'updatedAt');

        final wrongTypeUpdatedAt = Map<String, dynamic>.from(validFullJson)
          ..['updatedAt'] = 123456789;
        expectParseException(wrongTypeUpdatedAt, 'updatedAt');
      });

      test('6.10. Sai trường note (phải là String hoặc null)', () {
        final wrongTypeNote = Map<String, dynamic>.from(validFullJson)
          ..['note'] = 123;
        expectParseException(wrongTypeNote, 'note');
      });
    });
  });
}
