import '../../core/errors/app_exception.dart';
import '../../core/utils/timestamp_mixin.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_type.dart';

/// Mô hình truyền tải dữ liệu (DTO - Data Transfer Object) cho giao dịch thu - chi.
///
/// **Lý do thiết kế Tầng Data Model:**
/// 1. Tách biệt DTO và Domain Entity: `TransactionModel` chịu trách nhiệm cấu trúc hóa
///    và tuần tự hóa (serialization/deserialization) dữ liệu thô (JSON, Map, SQLite, Disk File).
///    Trong khi đó, `Transaction` ở tầng Domain chỉ chứa các kiểu dữ liệu giàu ngữ nghĩa (Rich Types: `Money`, `Category`).
/// 2. Áp dụng Mixin (R3): Tái sử dụng `TimestampMixin` ở tầng Data để kiểm tra mốc thời gian sửa đổi
///    giữa các phiên bản bản ghi mà không cần lặp code.
/// 3. Ranh giới trách nhiệm (Schema Validation vs Business Validation):
///    - `TransactionModel` CHỈ kiểm tra tính toàn vẹn của lược đồ dữ liệu (Schema Integrity):
///      đủ trường, đúng kiểu (int, String, ISO-8601 date), thuộc danh mục hợp lệ.
///    - `TransactionModel` KHÔNG kiểm tra quy tắc nghiệp vụ (ví dụ: số tiền > 0, ngày không quá xa tương lai);
///      các quy tắc này hoàn toàn thuộc thẩm quyền của Domain Layer (`TransactionRules`).
class TransactionModel with TimestampMixin {
  /// Mã định danh giao dịch dạng chuỗi.
  final String id;

  /// Loại giao dịch dạng chuỗi thô ('income' hoặc 'expense').
  final String type;

  /// Tiêu đề giao dịch.
  final String title;

  /// Số tiền giao dịch tính bằng số nguyên đồng VND.
  final int amount;

  /// Danh mục giao dịch dạng chuỗi ('food', 'salary'...).
  final String category;

  /// Ngày phát sinh giao dịch.
  final DateTime date;

  /// Ghi chú kèm theo (nếu có).
  final String? note;

  @override
  final DateTime createdAt;

  @override
  final DateTime? updatedAt;

  /// Khởi tạo một đối tượng [TransactionModel] với các giá trị thô.
  const TransactionModel({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  /// Factory chuyển đổi dữ liệu thô [json] thành [TransactionModel].
  ///
  /// Mọi trường hợp dữ liệu JSON sai lệch (thiếu trường, sai kiểu, không phải Map,
  /// enum không tồn tại, ngày sai định dạng) đều được chuyển đổi an toàn thành [ParseException].
  /// Phương thức đảm bảo KHÔNG bao giờ để lọt các lỗi thô như `TypeError`, `CastError`,
  /// hay `FormatException` ra ngoài.
  factory TransactionModel.fromJson(Object? json) {
    if (json == null || json is! Map) {
      throw ParseException(
        message:
            'Invalid JSON: Expected a Map but got ${json?.runtimeType ?? 'null'}',
        originalError: json,
        stackTrace: StackTrace.current,
      );
    }

    try {
      final map = json;

      // 1. Kiểm tra trường [id]
      final rawId = map['id'];
      if (rawId == null || rawId is! String) {
        throw const ParseException(
          message: 'Invalid or missing field [id]: must be a String',
        );
      }

      // 2. Kiểm tra trường [type]
      final rawType = map['type'];
      if (rawType == null || rawType is! String) {
        throw const ParseException(
          message: 'Invalid or missing field [type]: must be a String',
        );
      }
      if (rawType != 'income' && rawType != 'expense') {
        throw ParseException(
          message:
              "Invalid field [type]: expected 'income' or 'expense', got '$rawType'",
        );
      }

      // 3. Kiểm tra trường [title]
      final rawTitle = map['title'];
      if (rawTitle == null || rawTitle is! String) {
        throw const ParseException(
          message: 'Invalid or missing field [title]: must be a String',
        );
      }

      // 4. Kiểm tra trường [amount] (phải là số nguyên, không được có phần thập phân)
      final rawAmount = map['amount'];
      if (rawAmount == null) {
        throw const ParseException(
          message: 'Missing required field [amount]',
        );
      }
      if (rawAmount is! num || (rawAmount is double && rawAmount % 1 != 0)) {
        throw ParseException(
          message:
              'Invalid field [amount]: must be an integer (VND), got $rawAmount',
        );
      }
      final amount = rawAmount.toInt();

      // 5. Kiểm tra trường [category]
      final rawCategory = map['category'];
      if (rawCategory == null || rawCategory is! String) {
        throw const ParseException(
          message: 'Invalid or missing field [category]: must be a String',
        );
      }
      if (!_isValidCategoryString(rawCategory)) {
        throw ParseException(
          message: "Invalid field [category]: unknown category '$rawCategory'",
        );
      }

      // 6. Kiểm tra trường [date] (ISO-8601)
      final rawDate = map['date'];
      if (rawDate == null || rawDate is! String) {
        throw const ParseException(
          message:
              'Invalid or missing field [date]: must be an ISO-8601 String',
        );
      }
      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) {
        throw ParseException(
          message:
              "Invalid field [date]: unable to parse ISO-8601 date string '$rawDate'",
        );
      }

      // 7. Kiểm tra trường [note] (tùy chọn)
      final rawNote = map['note'];
      if (rawNote != null && rawNote is! String) {
        throw const ParseException(
          message: 'Invalid field [note]: must be a String or null',
        );
      }

      // 8. Kiểm tra trường [createdAt] (ISO-8601)
      final rawCreatedAt = map['createdAt'];
      if (rawCreatedAt == null || rawCreatedAt is! String) {
        throw const ParseException(
          message:
              'Invalid or missing field [createdAt]: must be an ISO-8601 String',
        );
      }
      final parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
      if (parsedCreatedAt == null) {
        throw ParseException(
          message:
              "Invalid field [createdAt]: unable to parse ISO-8601 date string '$rawCreatedAt'",
        );
      }

      // 9. Kiểm tra trường [updatedAt] (tùy chọn, ISO-8601)
      final rawUpdatedAt = map['updatedAt'];
      DateTime? parsedUpdatedAt;
      if (rawUpdatedAt != null) {
        if (rawUpdatedAt is! String) {
          throw const ParseException(
            message:
                'Invalid field [updatedAt]: must be an ISO-8601 String or null',
          );
        }
        parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
        if (parsedUpdatedAt == null) {
          throw ParseException(
            message:
                "Invalid field [updatedAt]: unable to parse ISO-8601 date string '$rawUpdatedAt'",
          );
        }
      }

      return TransactionModel(
        id: rawId,
        type: rawType,
        title: rawTitle,
        amount: amount,
        category: rawCategory,
        date: parsedDate,
        note: rawNote,
        createdAt: parsedCreatedAt,
        updatedAt: parsedUpdatedAt,
      );
    } on ParseException {
      // Giữ nguyên ParseException có message chi tiết về từng field
      rethrow;
    } catch (e, st) {
      // Bọc các ngoại lệ khác (như TypeError) thành ParseException
      throw ParseException(
        message: 'Failed to deserialize TransactionModel: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Khởi tạo [TransactionModel] từ thực thể [Transaction] của tầng Domain.
  factory TransactionModel.fromEntity(Transaction entity) {
    return TransactionModel(
      id: entity.id,
      type: _typeToString(entity.type),
      title: entity.title,
      amount: entity.amount.amount,
      category: _categoryToString(entity.category),
      date: entity.date,
      note: entity.note,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Chuyển đổi [TransactionModel] sang thực thể [Transaction] giàu ngữ nghĩa của tầng Domain.
  Transaction toEntity() {
    return Transaction(
      id: id,
      type: _parseType(type),
      title: title,
      amount: Money(amount),
      category: _parseCategory(category),
      date: date,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Chuyển đổi đối tượng sang `Map<String, dynamic>` để lưu trữ hoặc gửi qua mạng.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // --- Các hàm tiện ích chuyển đổi Enum <-> Chuỗi (Không dùng enum.index) ---

  static String _typeToString(TransactionType type) => type.name;

  static TransactionType _parseType(String typeStr) {
    switch (typeStr) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      default:
        throw ParseException(
          message: "Unsupported transaction type '$typeStr'",
        );
    }
  }

  static String _categoryToString(Category category) => category.name;

  static bool _isValidCategoryString(String catStr) {
    for (final c in Category.values) {
      if (c.name == catStr) return true;
    }
    return false;
  }

  static Category _parseCategory(String categoryStr) {
    for (final c in Category.values) {
      if (c.name == categoryStr) return c;
    }
    throw ParseException(
      message: "Unsupported category '$categoryStr'",
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          amount == other.amount &&
          category == other.category &&
          date == other.date &&
          note == other.note &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        title,
        amount,
        category,
        date,
        note,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'TransactionModel(id: $id, type: $type, title: $title, amount: $amount, date: $date)';
}
