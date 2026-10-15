import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';

/// Các tiện ích hiển thị giao diện cho [Category].
extension CategoryPresentationX on Category {
  /// Biểu tượng Material Icon tương ứng với từng danh mục chi tiêu/thu nhập.
  IconData get icon {
    return switch (this) {
      Category.food => Icons.restaurant_rounded,
      Category.transport => Icons.directions_car_rounded,
      Category.shopping => Icons.shopping_bag_rounded,
      Category.bills => Icons.receipt_long_rounded,
      Category.health => Icons.medical_services_rounded,
      Category.entertainment => Icons.sports_esports_rounded,
      Category.salary => Icons.payments_rounded,
      Category.other => Icons.category_rounded,
    };
  }

  /// Tên tiếng Việt thân thiện của danh mục để hiển thị trên giao diện người dùng.
  String get label {
    return switch (this) {
      Category.food => 'Ăn uống',
      Category.transport => 'Di chuyển',
      Category.shopping => 'Mua sắm',
      Category.bills => 'Hóa đơn',
      Category.health => 'Sức khỏe',
      Category.entertainment => 'Giải trí',
      Category.salary => 'Tiền lương',
      Category.other => 'Khác',
    };
  }
}
