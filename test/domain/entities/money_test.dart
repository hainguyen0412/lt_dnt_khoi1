import 'package:expense_tracker/domain/entities/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T-103: Money Value Object Tests', () {
    test('1. Named constructor Money.zero() tạo số tiền bằng 0', () {
      const zero = Money.zero();
      expect(zero.amount, equals(0));
      expect(zero.isPositive, isFalse);
      expect(zero.toString(), equals('0 VND'));
    });

    test('2. Constructor chấp nhận cả số âm mà không ném ngoại lệ', () {
      const negative = Money(-50000);
      expect(negative.amount, equals(-50000));
      expect(negative.isPositive, isFalse);
    });

    test('3. Toán tử cộng (+) và trừ (-) giữa hai đối tượng Money', () {
      const m1 = Money(100000);
      const m2 = Money(30000);

      final sum = m1 + m2;
      final diff = m1 - m2;
      final negativeDiff = m2 - m1;

      expect(sum.amount, equals(130000));
      expect(diff.amount, equals(70000));
      expect(negativeDiff.amount, equals(-70000));
    });

    test('4. So sánh compareTo và thứ tự', () {
      const mSmall = Money(10000);
      const mEqual = Money(10000);
      const mBig = Money(50000);

      expect(mSmall.compareTo(mEqual), equals(0));
      expect(mSmall.compareTo(mBig), lessThan(0));
      expect(mBig.compareTo(mSmall), greaterThan(0));
    });

    test('5. So sánh bằng nhau (==) và hashCode', () {
      const a = Money(25000);
      const b = Money(25000);
      const c = Money(50000);

      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
    });
  });
}
