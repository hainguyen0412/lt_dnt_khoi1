import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'error_logger.dart';
import 'log_entry.dart';

/// Bộ ghi nhật ký lỗi bền vững vào tệp tin cục bộ (`app_errors.log`),
/// hỗ trợ đa nền tảng (Web & Native) với cơ chế Graceful Fallback vào bộ nhớ đệm.
///
/// **Lý do thiết kế:**
/// - **Lưu trữ bền vững (Persistence):** Khi người dùng gặp lỗi ngoài thực tế (production),
///   console không thể xem được. [FileLogger] lưu lại toàn bộ lỗi dưới dạng JSON Lines
///   để phục vụ màn hình xem log hoặc gửi báo cáo lỗi về sau.
/// - **Hỗ trợ đa nền tảng (Web & Native Graceful Fallback):** Trên nền tảng Web (`kIsWeb`),
///   `dart:io` và `path_provider` không hỗ trợ hệ thống file cục bộ. [FileLogger] tự động
///   duy trì [_memoryBuffer] trong bộ nhớ (tối đa 500 entry) làm tầng lưu trữ dự phòng.
///   Khi chạy trên Web, `readAll()` tự động trả về nhật ký từ [_memoryBuffer], đảm bảo
///   màn hình `LogViewerScreen` hoạt động nhất quán, đầy đủ dữ liệu trên mọi nền tảng.
/// - **Dependency Injection:** Cho phép inject `directoryProvider` qua constructor để
///   Unit Test chạy độc lập trên thư mục tạm (`Directory.systemTemp`) mà không phụ thuộc
///   vào native platform channel của `path_provider`.
/// - **Hàng đợi ghi tuần tự (Sequential Future Queue / Mutex):** Sử dụng cơ chế nối chuỗi
///   `Future` để tuần tự hóa các thao tác I/O, ngăn chặn hiện tượng race condition làm lẫn dòng
///   hoặc hỏng file khi có nhiều ngoại lệ xảy ra đồng thời.
/// - **Xoay vòng log (Log Pruning):** Giới hạn tối đa [maxEntries] = 500 entry. Khi vượt quá,
///   tự động cắt bỏ các entry cũ nhất để tiết kiệm dung lượng bộ nhớ thiết bị.
/// - **Khả năng phục hồi (Resilience):** Bỏ qua các dòng hỏng khi đọc, không bao giờ để crash.
/// - **Phòng thủ ngoại lệ tuyệt đối:** Không bao giờ ném lỗi ra ngoài. Nếu ghi file thất bại,
///   ghi log an toàn qua `dart:developer.log` và bảo toàn dữ liệu trong [_memoryBuffer].
class FileLogger implements ErrorLogger {
  /// Tên tệp tin nhật ký lỗi lưu trữ cục bộ.
  static const String logFileName = 'app_errors.log';

  /// Số lượng bản ghi lỗi tối đa được lưu trữ trong tệp tin.
  static const int maxEntries = 500;

  final Future<Directory> Function() _directoryProvider;

  /// Bộ nhớ đệm dự phòng trong RAM (In-Memory Fallback) phục vụ môi trường Web
  /// hoặc khi I/O tệp tin không khả dụng.
  final List<LogEntry> _memoryBuffer = <LogEntry>[];

  // Khóa tuần tự hóa (Mutex Lock) đảm bảo mọi thao tác ghi/đọc/xóa diễn ra tuần tự.
  Future<void> _lock = Future<void>.value();

  /// Khởi tạo [FileLogger] với [directoryProvider] tùy chọn (mặc định là [getApplicationDocumentsDirectory]).
  FileLogger({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final next = _lock.then((_) => action(), onError: (Object _) => action());
    _lock = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<File> _getLogFile() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$logFileName');
  }

  @override
  Future<void> log(LogEntry entry) async {
    return _synchronized(() async {
      // 1. Luôn thêm vào memory buffer trước (giới hạn tối đa maxEntries = 500 dòng)
      _memoryBuffer.add(entry);
      if (_memoryBuffer.length > maxEntries) {
        _memoryBuffer.removeAt(0);
      }

      // 2. Thử ghi xuống tệp tin vật lý (nếu là Native platform)
      try {
        final file = await _getLogFile();
        List<String> lines = <String>[];
        if (await file.exists()) {
          try {
            lines = await file.readAsLines();
          } catch (_) {
            lines = <String>[];
          }
        }

        // Thêm entry mới được tuần tự hóa dạng JSON
        lines.add(jsonEncode(entry.toJson()));

        // Giới hạn tối đa 500 entries, cắt bỏ các dòng cũ nhất ở đầu danh sách (FIFO)
        if (lines.length > maxEntries) {
          lines = lines.sublist(lines.length - maxEntries);
        }

        // Ghi lại toàn bộ nội dung và flush trực tiếp xuống đĩa
        await file.writeAsString(
          lines.map((String line) => '$line\n').join(),
          flush: true,
        );
      } catch (e, st) {
        // NGOẠI LỆ HỢP LỆ DUY NHẤT CỦA QUY TẮC "KHÔNG CATCH RỖNG":
        // FileLogger là chốt chặn cuối cùng trong pipeline xử lý và ghi nhận ngoại lệ.
        // Nếu thao tác ghi file gặp sự cố (ví dụ: trên Web, ổ đĩa đầy, mất quyền ghi),
        // logger tuyệt đối KHÔNG ĐƯỢC ném ngoại lệ ra ngoài làm sập ứng dụng.
        // Dữ liệu vẫn được bảo toàn an toàn trong _memoryBuffer.
        developer.log(
          'FileLogger gặp sự cố khi ghi log vào file: $e',
          name: 'FileLogger',
          error: e,
          stackTrace: st,
        );
      }
    });
  }

  @override
  Future<List<LogEntry>> readAll() async {
    return _synchronized(() async {
      try {
        final file = await _getLogFile();
        if (!await file.exists()) {
          if (_memoryBuffer.isNotEmpty) {
            return _memoryBuffer.reversed.toList();
          }
          return const <LogEntry>[];
        }

        final lines = await file.readAsLines();
        final entries = <LogEntry>[];

        // Duyệt theo thứ tự mới nhất trước (đảo ngược dòng)
        for (final line in lines.reversed) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          try {
            final dynamic decoded = jsonDecode(trimmed);
            if (decoded is Map<String, dynamic>) {
              entries.add(LogEntry.fromJson(decoded));
            }
          } catch (_) {
            // Bỏ qua dòng hỏng mà không làm gián đoạn việc đọc các dòng khác
            continue;
          }
        }

        if (entries.isEmpty && _memoryBuffer.isNotEmpty) {
          return _memoryBuffer.reversed.toList();
        }

        return entries;
      } catch (e, st) {
        developer.log(
          'FileLogger gặp sự cố khi đọc log từ file: $e',
          name: 'FileLogger',
          error: e,
          stackTrace: st,
        );
        // Graceful fallback: trên Web hoặc khi gặp UnsupportedError / MissingPluginException,
        // trả về danh sách từ _memoryBuffer (đảo ngược để bản ghi mới nhất lên đầu).
        if (kIsWeb ||
            e is UnsupportedError ||
            e is MissingPluginException ||
            e.runtimeType.toString().contains('MissingPluginException')) {
          return _memoryBuffer.reversed.toList();
        }
        return const <LogEntry>[];
      }
    });
  }

  @override
  Future<void> clear() async {
    return _synchronized(() async {
      _memoryBuffer.clear();
      try {
        final file = await _getLogFile();
        if (await file.exists()) {
          await file.writeAsString('', flush: true);
        }
      } catch (e, st) {
        developer.log(
          'FileLogger gặp sự cố khi xóa file log: $e',
          name: 'FileLogger',
          error: e,
          stackTrace: st,
        );
      }
    });
  }
}
