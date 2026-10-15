# NGÂN HÀNG CÂU HỎI PHẢN BIỆN ĐỒ ÁN (QA_BANK.md)

> **Môn học:** Lập trình ứng dụng di động nâng cao (Advanced Mobile Programming)  
> **Chủ đề 01:** Sổ Chi Tiêu Cá Nhân (Expense Tracker)  
> **Tài liệu phục vụ:** Ôn tập và phản biện đồ án trước Giảng viên phản biện  
> **Tổng số câu hỏi:** 30 câu hỏi chuyên sâu (chia làm 6 nhóm chủ đề, kèm ít nhất 6 câu hỏi bẫy)  
> **Thang điểm đánh giá:** 1 – 5 điểm theo độ chính xác, bản chất công nghệ và khả năng chỉ code thực tế.  

---

## 📌 BẢNG TỔNG HỢP CẤU TRÚC 30 CÂU HỎI

| Nhóm chủ đề | Số câu | Câu hỏi bẫy (Trọng điểm) |
| :--- | :---: | :--- |
| **Nhóm 1: Lập trình hướng đối tượng (OOP) nâng cao** | 5 câu | Câu 5 (Bẫy Sealed Class & Tính đóng) |
| **Nhóm 2: Design Patterns & Phân tầng kiến trúc** | 5 câu | Câu 8 (Bẫy Singleton vs Dependency Injection) |
| **Nhóm 3: Domain Layer thuần khiết & Ràng buộc nghiệp vụ** | 5 câu | Câu 11 (Bẫy Phụ thuộc trong Clean Architecture) |
| **Nhóm 4: Xử lý ngoại lệ, Pipeline & Error Boundary** | 5 câu | Câu 16 (Bẫy Repository throw error), Câu 18 (Bẫy Giới hạn Error Boundary) |
| **Nhóm 5: Chi tiết Code ("Dòng này làm gì, bỏ đi thì sao?")** | 5 câu | Câu 21 (Bẫy unmounted notifier), Câu 24 (Bẫy nuốt lỗi cache) |
| **Nhóm 6: Quyết định thiết kế & Sử dụng AI có kiểm soát** | 5 câu | Câu 26 (Bẫy Thư viện dartz/fpdart vs Result tự viết) |

---

## NHÓM 1: LẬP TRÌNH HƯỚNG ĐỐI TƯỢNG (OOP) NÂNG CAO TRONG DART 3

---

### Câu 1: Named Constructor mang lại giá trị gì cho Clean Architecture?
- **Độ khó:** ⭐
- **Mã nguồn dẫn chứng:** `lib/domain/entities/money.dart` (Dòng 19 – 23), `lib/domain/entities/transaction_summary.dart` (Dòng 26 – 31).
- **Đáp án ngắn gọn dễ nói:**
  - Named constructor giúp code tự sinh tài liệu (self-documenting), thể hiện rõ mục đích nghiệp vụ thay vì truyền tham số tùy tiện.
  - Ví dụ `Money.zero()` hoặc `TransactionSummary.empty()` tạo ra trạng thái rỗng an toàn và tường minh mà không cần hardcode số 0 hoặc null.
  - Tạo immutability với từ khóa `const`, cho phép Dart tối ưu hóa cấp phát bộ nhớ tại thời điểm biên dịch (canonicalized instances).

---

### Câu 2: Tại sao dùng Factory Constructor trong Model thay vì static method thông thường?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/data/models/transaction_model.dart` (Dòng 68 – 76).
- **Đáp án ngắn gọn dễ nói:**
  - Cú pháp chuẩn của Dart (`TransactionModel.fromJson(json)`), cho phép gọi giống như một constructor thông thường mà caller không cần biết chi tiết khởi tạo bên trong.
  - Cho phép kiểm tra điều kiện đầu vào và chủ động ném `ParseException` trước khi tạo instance, bảo đảm đối tượng được tạo ra luôn hợp lệ 100%.
  - Cho phép đa hình: Factory constructor có thể trả về một lớp con kế thừa hoặc instance lưu trong cache, điều mà constructor thông thường không thể làm được.

---

### Câu 3: Bản chất của Dart Mixin là gì? Tại sao nhóm dùng Mixin thay vì kế thừa class thông thường?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/core/utils/validatable_mixin.dart` (Dòng 18 – 35), `lib/core/utils/loggable_mixin.dart` (Dòng 6 – 16).
- **Đáp án ngắn gọn dễ nói:**
  - Dart chỉ hỗ trợ **đơn kế thừa (single inheritance)**, trong khi một Entity hay Model có thể cần nhiều hành vi dùng chung (vừa validate được, vừa log được, vừa gắn timestamp).
  - Mixin hiện thực hóa nguyên lý **Composition over Inheritance**: "nhúng" các hàm có sẵn (`isValid`, `ensureValid()`, `logTag`) vào class mà không làm xáo trộn cây phả hệ kế thừa.
  - Tránh được "Kim tự tháp kế thừa" (fragile base class problem) khi lớp cha thay đổi làm ảnh hưởng dây chuyền đến các lớp con.

---

### Câu 4: Vì sao nhóm tự thiết kế Generic `Result<T>` thay vì trả về `dynamic` hoặc `Object?`?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/core/utils/result.dart` (Dòng 17 – 34).
- **Đáp án ngắn gọn dễ nói:**
  - Generic `<T>` bảo đảm an toàn kiểu dữ liệu tại thời điểm biên dịch (**compile-time type safety**); nếu trả về `dynamic` thì IDE không gợi ý code và mọi lỗi sai kiểu chỉ nổ ra tại runtime lúc app chạy.
  - `Result<T>` ép buộc phía gọi (UI / Notifier) phải biết rõ dữ liệu thành công có kiểu gì (ví dụ `Result<List<Transaction>>`) hoặc thất bại là `AppException`.
  - Hỗ trợ các hàm bậc cao dạng functional (`fold`, `map`) giúp biến đổi dữ liệu an toàn mà không cần ép kiểu thủ công (`as Type`).

---

### Câu 5 [BẪY]: `sealed class` trong Dart 3 khác gì `abstract class`? Nếu em khai báo thêm một lớp con của `AppException` ở thư viện khác thì có được không?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/core/errors/app_exception.dart` (Dòng 30 – 41).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** Tuyệt đối KHÔNG THỂ tạo lớp con ở file/thư viện khác! Trình biên dịch Dart sẽ báo lỗi ngay lập tức vì `sealed class` có **tính đóng (closed hierarchy)**: toàn bộ các lớp con bắt buộc phải nằm chung trong cùng một file thư viện.
  - **Khác biệt cốt lõi:** `abstract class` cho phép bất kỳ ai kế thừa ở bất cứ đâu; còn `sealed class` khóa chặt cây kế thừa.
  - **Lợi ích:** Cho phép trình biên dịch kiểm tra tính vét cạn (**exhaustive pattern matching**). Trong lệnh `switch`, nếu ta quên xử lý 1 loại lỗi (ví dụ quên `ParseException`), Dart sẽ báo lỗi biên dịch, không bao giờ để sót case.

---

## NHÓM 2: DESIGN PATTERNS & PHÂN TẦNG KIẾN TRÚC

---

### Câu 6: Tại sao interface `TransactionRepository` lại nằm ở tầng Domain, trong khi `TransactionRepositoryImpl` lại nằm ở tầng Data?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/domain/repositories/transaction_repository.dart` (Dòng 18 – 45), `lib/data/repositories/transaction_repository_impl.dart` (Dòng 33 – 45).
- **Đáp án ngắn gọn dễ nói:**
  - Đây là sự áp dụng triệt để của nguyên lý **Dependency Inversion Principle (DIP)** trong SOLID.
  - Tầng Domain là trung tâm nghiệp vụ, nó không được phép phụ thuộc vào chi tiết kỹ thuật (Database, HTTP, SharedPreferences). Domain tự đặt ra "hợp đồng" (interface) nó cần.
  - Tầng Data là tầng chi tiết bên ngoài, bắt buộc phải phụ thuộc ngược vào Domain để hiện thực hóa hợp đồng đó. Nhờ vậy, ta có thể đổi từ Fake API sang Firebase mà không sửa 1 dòng code nào ở Domain.

---

### Câu 7: Phân biệt Factory Pattern (`ExceptionFactory.from`) và Factory Constructor (`TransactionModel.fromJson`) trong dự án?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/core/errors/exception_factory.dart` (Dòng 42 – 85), `lib/data/models/transaction_model.dart` (Dòng 68 – 76).
- **Đáp án ngắn gọn dễ nói:**
  - `TransactionModel.fromJson` là **Factory Constructor** (tính năng cú pháp của ngôn ngữ Dart), dùng để khởi tạo chính đối tượng `TransactionModel`.
  - `ExceptionFactory.from` là **Factory Pattern** (mẫu thiết kế GoF): một lớp tiện ích tĩnh đóng vai trò phân loại tập trung. Đầu vào là một `Object error` thô bất kỳ, đầu ra là một trong 8 lớp con cụ thể của `AppException`.

---

### Câu 8 [BẪY]: `FileLogger` và `ErrorHandler` trong dự án có phải là Singleton không? Tại sao nhóm không dùng `FileLogger.instance`?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/core/error_handling/file_logger.dart` (Dòng 27 – 43), `lib/core/di/app_dependencies.dart` (Dòng 30 – 65), `lib/app.dart` (Dòng 48 – 61).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** KHÔNG PHẢI Singleton! Cả hai class đều có public constructor thông thường và được tiêm phụ thuộc thông qua **Dependency Injection (Composition Root)**.
  - **Lý do không dùng Singleton (`.instance`):** Singleton tạo ra phụ thuộc ẩn (hidden dependency), biến toàn cục khó kiểm soát, và cực kỳ khó viết Unit Test vì không thể cô lập hoặc thay thế mock object.
  - **Cách nhóm làm:** Tạo instance một lần duy nhất tại `AppDependencies` rồi cung cấp xuống widget tree qua `Provider`. Trong Unit Test, ta có thể dễ dàng truyền mock logger hoặc directory tạm.

---

### Câu 9: Pipeline Pattern trong `ErrorHandler` gồm những bước nào? Tại sao không gộp lại thành 1 hàm xử lý cho nhanh?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/core/error_handling/error_handler.dart` (Dòng 43 – 57).
- **Đáp án ngắn gọn dễ nói:**
  - Gồm đúng 5 bước tuần tự: (1) **Normalize** (chuẩn hóa lỗi thô) -> (2) **Classify** (phân loại mức độ) -> (3) **Log** (ghi nhật ký) -> (4) **Decide Retry** (đánh giá thử lại) -> (5) **Translate** (dịch tiếng Việt).
  - Tách bạch 5 bước tuân thủ **Single Responsibility Principle (SRP)**: mỗi bước chỉ làm 1 việc duy nhất. Nếu sau này cần đổi cách ghi log (lên Firebase Crashlytics) hoặc đổi ngôn ngữ (đa ngôn ngữ i18n), ta chỉ cần sửa đúng bước đó mà không làm hỏng các bước còn lại.

---

### Câu 10: Value Object Pattern: Tại sao phải tạo class `Money` thay vì dùng kiểu `int` hay `double`?
- **Độ khó:** ⭐
- **Mã nguồn dẫn chứng:** `lib/domain/entities/money.dart` (Dòng 12 – 45).
- **Đáp án ngắn gọn dễ nói:**
  - Tránh lỗi chống mẫu **Primitive Obsession** (lạm dụng kiểu nguyên thủy).
  - Class `Money` đóng gói các quy tắc nghiệp vụ tiền tệ: không dùng `double` để tránh lỗi sai số dấu phẩy động (floating-point precision issue); nạp chồng toán tử `+`, `-` để cộng trừ tiền an toàn; có sẵn getter `isPositive`.
  - Tạo tính bất biến (`immutable`): giá trị tiền một khi tạo ra là không thể bị sửa lén từ bên ngoài.

---

## NHÓM 3: DOMAIN LAYER THUẦN KHIẾT & RÀNG BUỘC NGHIỆP VỤ

---

### Câu 11 [BẪY]: Giả sử em cần dùng `Color` hoặc `IconData` cho `Category` trong Domain, em có được `import 'package:flutter/material.dart'` vào Domain không? Vì sao?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/domain/entities/category.dart` (Dòng 1 – 20), `lib/presentation/utils/category_extension.dart` (Dòng 1 – 31).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** TUYỆT ĐỐI KHÔNG! Tầng Domain phải là **Pure Dart**. Nếu import `flutter/material.dart` vào Domain, kiến trúc Clean Architecture bị phá vỡ hoàn toàn, Domain bị dính chặt vào UI framework.
  - **Giải pháp chuẩn của nhóm:** Trong `Category` ở Domain chỉ khai báo enum thuần túy (`food`, `bills`, `salary`...). Phần ánh xạ ra icon và màu sắc hiển thị được đưa sang tầng Presentation dưới dạng extension `CategoryPresentationX` tại `lib/presentation/utils/category_extension.dart`.

---

### Câu 12: Tại sao trong Use Case `AddTransaction`, nhóm lại tiêm `clock` và `idGenerator` qua Constructor?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/domain/usecases/add_transaction.dart` (Dòng 26 – 37).
- **Đáp án ngắn gọn dễ nói:**
  - Để loại bỏ sự phụ thuộc vào trạng thái môi trường (non-deterministic behavior). Nếu gọi trực tiếp `DateTime.now()`, Unit Test sẽ bị phụ thuộc vào đồng hồ hệ thống và dễ bị sai lệch khi test các mốc biên (ví dụ giao dịch tương lai).
  - Nhờ tiêm `clock: () => DateTime(2026, 10, 15)`, ta có thể "đóng băng" thời gian trong Unit Test để kiểm thử chính xác 100% quy tắc nghiệp vụ.

---

### Câu 13: Tại sao không kiểm tra tính hợp lệ dữ liệu ngay trên `TextFormField` của UI mà lại phải đưa validation vào `TransactionRules` ở Domain?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/domain/validation/transaction_rules.dart` (Dòng 23 – 65), `lib/presentation/screens/transaction_form_screen.dart`.
- **Đáp án ngắn gọn dễ nói:**
  - UI validation chỉ phục vụ trải nghiệm người dùng (UX) bề mặt. Domain Validation mới là **người gác cổng nghiệp vụ cuối cùng (source of truth)**.
  - Nếu sau này ứng dụng có thêm nguồn tạo giao dịch khác (nhập từ file CSV, nhận từ thông báo ngân hàng, đồng bộ nền), dữ liệu không đi qua Form UI nhưng Domain Rules vẫn bảo đảm 100% không bao giờ có giao dịch tiền âm lọt vào cơ sở dữ liệu.

---

### Câu 14: Tính bất biến (Immutability) của Entity `Transaction` có ý nghĩa gì? Nếu muốn cập nhật giao dịch thì làm thế nào?
- **Độ khó:** ⭐
- **Mã nguồn dẫn chứng:** `lib/domain/entities/transaction.dart` (Dòng 10 – 35), `lib/domain/entities/transaction.dart` (`copyWith`).
- **Đáp án ngắn gọn dễ nói:**
  - Tất cả các trường đều là `final`, ngăn chặn việc một hàm ở tầng UI vô tình sửa đổi trực tiếp dữ liệu đang hiển thị làm sai lệch trạng thái state.
  - Khi cần cập nhật, ta sử dụng phương thức `copyWith()` để tạo ra một instance mới với các trường cần sửa, giữ nguyên các trường còn lại. Điều này giúp Notifier dễ dàng so sánh state cũ và mới để kích hoạt vẽ lại UI.

---

### Câu 15: Tại sao nhóm tách thành 6 file Use Case riêng biệt thay vì gom chung thành một file `TransactionService`?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** Thư mục `lib/domain/usecases/` (`get_transactions.dart`, `add_transaction.dart`, ...).
- **Đáp án ngắn gọn dễ nói:**
  - Tuân thủ nguyên lý **Single Responsibility Principle (SRP)** và **Interface Segregation Principle (ISP)**.
  - Mỗi class Use Case chỉ đảm nhiệm 1 ca sử dụng nghiệp vụ duy nhất thông qua hàm `call()`.
  - Màn hình nào cần chức năng nào thì chỉ inject đúng Use Case đó, không bị thừa thãi dependencies và giúp việc viết Unit Test cho từng chức năng trở nên độc lập, dễ dàng.

---

## NHÓM 4: XỬ LÝ NGOẠI LỆ, PIPELINE & ERROR BOUNDARY

---

### Câu 16 [BẪY]: Tại sao `TransactionRepositoryImpl` tuyệt đối không được ném exception (`throw`) ra ngoài mà phải trả về `Result.failure`?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/data/repositories/transaction_repository_impl.dart` (Dòng 68 – 112).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** Việc ném exception qua ranh giới kiến trúc (boundary crossing) làm mất tính kiểm soát luồng thực thi (flow control) và buộc tầng trên phải nhớ đặt try-catch.
  - **Bản chất kỹ thuật:** Trong Clean Architecture, lỗi I/O hay lỗi máy chủ là **kết quả có thể dự đoán được (expected failure)** chứ không phải lỗi lập trình (bug). Do đó, việc đóng gói lỗi vào `Result.failure(appEx)` giúp biến lỗi thành dữ liệu có kiểu rõ ràng (type-safe return value), bảo đảm không làm sập ứng dụng.

---

### Câu 17: Khối `finally` trong phương thức `_run` của `TransactionNotifier` có mục đích thực tế gì? Bỏ đi thì sao?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/presentation/state/transaction_notifier.dart` (Dòng 193 – 198).
- **Đáp án ngắn gọn dễ nói:**
  - Khối `finally` bảo đảm 100% dòng lệnh `_isSubmitting = false;` và `_safeNotifyListeners();` luôn luôn được gọi, kể cả khi khối `action()` bên trong ném ra lỗi runtime chưa lường trước.
  - **Nếu bỏ khối `finally` đi:** Khi xảy ra lỗi ngoại lệ, biến `_isSubmitting` sẽ mãi mãi kẹt ở giá trị `true`, nút bấm trên giao diện sẽ bị khóa đơ vĩnh viễn và người dùng không thể thao tác tiếp được.

---

### Câu 18 [BẪY]: `ErrorBoundary` trong Flutter bắt được những loại lỗi nào và KHÔNG bắt được những loại lỗi nào?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/presentation/widgets/error_boundary.dart` (Dòng 53 – 66), `lib/core/error_handling/error_widget_setup.dart` (Dòng 20 – 35).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** Flutter KHÔNG có cơ chế try-catch bọc quanh widget con như React!
  - **ErrorBoundary bắt được:** Các lỗi nghiêm trọng do state thông báo qua `errorSource` (ValueListenable) và các lỗi render trong phương thức `build()` (thông qua `ErrorWidget.builder`).
  - **ErrorBoundary KHÔNG bắt được:** Lỗi bất đồng bộ ngoài widget tree (như `Future.delayed` ném lỗi), lỗi sự kiện nhấn nút (onPressed callback), và các lỗi validation thông thường (những lỗi này thuộc về SnackBar hoặc Global Hooks).

---

### Câu 19: Phân biệt vai trò của 3 tầng trong Global Safety Net (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`)?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/core/error_handling/global_error_hooks.dart` (Dòng 38 – 65), `lib/main.dart` (Dòng 20 – 35).
- **Đáp án ngắn gọn dễ nói:**
  - `FlutterError.onError`: Chuyên bắt các lỗi phát sinh bên trong Flutter Framework (lỗi layout, render, widget lifecycle).
  - `PlatformDispatcher.instance.onError`: Bắt các ngoại lệ bất đồng bộ (async errors) lọt ra ngoài framework ở cấp độ Engine/Isolate.
  - `runZonedGuarded`: Tạo một Zone an toàn bao quanh toàn bộ hàm `main()`, là chốt chặn cuối cùng bắt các unhandled error trong luồng microtask/event-loop của Dart.

---

### Câu 20: Trong `FileLogger`, cơ chế nào ngăn chặn hiện tượng race condition khi nhiều luồng cùng ghi log vào một file?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/core/error_handling/file_logger.dart` (Dòng 36 – 55).
- **Đáp án ngắn gọn dễ nói:**
  - `FileLogger` sử dụng biến `Future<void> _lock = Future.value();` làm khóa tuần tự hóa (**Sequential Future Queue / Mutex Lock**).
  - Mỗi khi có yêu cầu ghi log mới, hàm `_synchronized` sẽ nối tiếp `Future` mới vào đuôi của `_lock`. Nhờ vậy, mọi thao tác I/O mở file, ghi dòng JSON và đóng file đều diễn ra tuần tự 100%, không bao giờ bị lẫn byte hay hỏng cấu trúc dòng.

---

## NHÓM 5: CHI TIẾT CODE ("DÒNG NÀY LÀM GÌ, BỎ ĐI THÌ SAO?")

---

### Câu 21 [BẪY]: Trong `TransactionNotifier`, dòng `if (!_isDisposed) notifyListeners();` làm gì? Nếu bỏ `if (!_isDisposed)` đi thì sao?
- **Độ khó:** ⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/presentation/state/transaction_notifier.dart` (Dòng 98 – 102).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** Đây là lỗi rất phổ biến khi làm việc với `ChangeNotifier` trong ứng dụng thực tế.
  - Khi người dùng bấm nút và lập tức back khỏi màn hình, Widget bị unmount và Notifier bị `dispose()`. Nếu một tác vụ async (gọi API) hoàn thành sau đó và gọi `notifyListeners()`, Flutter framework sẽ ném ngay ngoại lệ crash: `"A ChangeNotifier was used after being disposed"`.
  - Kiểm tra `!_isDisposed` bảo vệ ứng dụng an toàn tuyệt đối trước các thao tác chuyển trang nhanh của người dùng.

---

### Câu 22: Trong `TransactionModel.fromJson`, dòng kiểm tra `if (json == null || json is! Map)` có ý nghĩa gì? Bỏ đi thì sao?
- **Độ khó:** ⭐
- **Mã nguồn dẫn chứng:** `lib/data/models/transaction_model.dart` (Dòng 68 – 76).
- **Đáp án ngắn gọn dễ nói:**
  - Đây là chốt chặn phòng thủ kiểu dữ liệu (defensive type check).
  - **Nếu bỏ đi:** Nếu API trả về chuỗi rỗng `""`, hoặc số `500`, hoặc `null` do lỗi mạng, Dart sẽ ném lỗi `TypeError` lúc ép kiểu `json as Map`.
  - Khi có dòng này: Toàn bộ dữ liệu sai cấu trúc đều được bắt ngay và chuyển thành `ParseException` có thông điệp rõ ràng, không làm app crash âm thầm.

---

### Câu 23: Trong `ExceptionFactory.from`, dòng `if (error is AppException) return error;` nhằm mục đích gì?
- **Độ khó:** ⭐
- **Mã nguồn dẫn chứng:** `lib/core/errors/exception_factory.dart` (Dòng 44 – 46).
- **Đáp án ngắn gọn dễ nói:**
  - Đảm bảo tính đẳng vi (Idempotency): Nếu đối tượng đầu vào vốn dĩ đã là một `AppException` chuẩn (ví dụ đã được ném từ tầng Model hoặc Domain), Factory sẽ trả về nguyên vẹn chính nó (identical instance).
  - Ngăn chặn việc bọc lỗi lặp lại (bọc trùng) thành các đối tượng lồng nhau kiểu `UnknownException(AppException(...))`, giữ nguyên vẹn mã lỗi và StackTrace gốc ban đầu.

---

### Câu 24 [BẪY]: Trong `TransactionRepositoryImpl.getAll`, tại sao khi ghi đè vào cache thất bại (`_localDataSource.replaceAll`), nhóm lại nuốt lỗi qua `_nonFatalReporter` thay vì trả về `Result.failure`?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/data/repositories/transaction_repository_impl.dart` (Dòng 76 – 81).
- **Đáp án ngắn gọn dễ nói:**
  - **Điểm bẫy:** Dữ liệu chính lấy từ Remote API đã thành công 100%! Việc lưu đệm vào cache chỉ là tác vụ phụ trợ (secondary concern).
  - Nếu vì ổ đĩa đầy hoặc lỗi ghi cache mà trả về `Failure`, người dùng sẽ không xem được danh sách dù máy chủ phản hồi hoàn toàn tốt.
  - Do đó, nhóm ghi nhận sự cố qua `_nonFatalReporter` để phục vụ debug và vẫn tự tin trả về `Success(remoteModels)` cho người dùng.

---

### Câu 25: Tại sao trong `ErrorBoundary.build`, nhóm viết `return childWidget ?? child;` thay vì `return childWidget!;`?
- **Độ khó:** ⭐
- **Mã nguồn dẫn chứng:** `lib/presentation/widgets/error_boundary.dart` (Dòng 64).
- **Đáp án ngắn gọn dễ nói:**
  - Tuân thủ quy tắc Clean Code và Effective Dart: Triệt tiêu hoàn toàn toán tử ép kiểu không null `!` (null assertion operator).
  - Sử dụng toán tử fallback `?? child` bảo đảm tính an toàn phòng thủ tuyệt đối (defensive programming), tránh mọi nguy cơ phát sinh lỗi `NullCheckObjectException` tại runtime.

---

## NHÓM 6: QUYẾT ĐỊNH THIẾT KẾ & SỬ DỤNG AI CÓ KIỂM SOÁT

---

### Câu 26 [BẪY]: Khi thiết kế kiến trúc, AI có thể gợi ý dùng thư viện `dartz` để lấy `Either<L, R>`. Tại sao nhóm lại tự viết `Result<T>`?
- **Độ khó:** ⭐⭐⭐ (Câu hỏi bẫy)
- **Mã nguồn dẫn chứng:** `lib/core/utils/result.dart` (Dòng 1 – 25).
- **Đáp án ngắn gọn dễ nói:**
  - `dartz` đã rất cũ, không được bảo trì, không tương thích tốt với Dart 3 Sealed Class và Record patterns.
  - `Either<L, R>` dùng khái niệm Left/Right mang nặng tính lập trình hàm trừu tượng, khó đọc, dễ gây nhầm lẫn quy ước đâu là lỗi, đâu là dữ liệu.
  - Tự viết `sealed class Result<T>` với hai lớp `Success<T>` và `Failure<T>` tận dụng 100% sức mạnh tính vét cạn của Dart 3, code trong sáng, dễ thuyết trình và đúng trọng tâm đề tài.

---

### Câu 27: Vì sao nhóm chọn `Provider` kết hợp `ChangeNotifier` thay vì dùng các framework phức tạp như `Bloc` hay `Riverpod`?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/app.dart` (Dòng 40 – 112), `lib/presentation/state/transaction_notifier.dart` (Dòng 33 – 55).
- **Đáp án ngắn gọn dễ nói:**
  - `Provider` là thư viện quản lý trạng thái chính thức được Google khuyến nghị trong tài liệu Flutter, hoàn toàn đáp ứng xuất sắc quy mô của ứng dụng Sổ chi tiêu.
  - Giảm thiểu tối đa mã nguồn thừa (boilerplate code) của Bloc (event, state, mapper cồng kềnh).
  - Nhóm vẫn đạt được tính chặt chẽ nhờ phân tách rõ ràng giữa `TransactionListState` (sealed class cho toàn màn hình) và các cờ cục bộ (`isSubmitting`, `fieldErrors`) cho form.

---

### Câu 28: Làm sao nhóm chứng minh được toàn bộ 223 tests trong dự án là "test có giá trị thật" chứ không phải test tự sinh đối phó?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `test/presentation/screens/transaction_form_screen_test.dart`, `test/core/error_handling/file_logger_test.dart`.
- **Đáp án ngắn gọn dễ nói:**
  - Toàn bộ 223 tests đều tuân thủ nghiêm ngặt mô hình **AAA (Arrange - Act - Assert)** với các assert có giá trị thực chất (kiểm tra đúng loại `AppException`, đúng mã code, đúng cờ `canRetry`, và đúng câu thông báo tiếng Việt).
  - Không có bất kỳ test nào kiểm tra getter/setter vô nghĩa.
  - Có các bài test nâng cao kiểm tra lỗi đồng thời (concurrent logging), test xoay vòng 500 dòng log, và test widget tương tác đẩy lỗi vào ErrorBoundary.

---

### Câu 29: Nếu sau này hệ thống chuyển từ `FakeRemoteDataSource` sang REST API thật (dùng `dio` hoặc `http`), nhóm cần thay đổi những file nào?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/data/datasources/`, `lib/core/di/app_dependencies.dart`.
- **Đáp án ngắn gọn dễ nói:**
  - Đây chính là vẻ đẹp của **Clean Architecture**:
    - Tầng **Domain** (Entities, Use Cases, Rules): **Không sửa bất kỳ dòng nào**.
    - Tầng **Presentation** (Screens, Widgets, Notifier): **Không sửa bất kỳ dòng nào**.
  - Nhóm chỉ cần tạo mới `ApiRemoteDataSource` trong `lib/data/datasources/` và sửa đúng 1 dòng khai báo tại Composition Root `lib/core/di/app_dependencies.dart`.

---

### Câu 30: Trong Sprint 4, nhóm đã thực hiện refactoring Clean Code (T-402) như thế nào để bảo đảm không làm thay đổi hành vi của ứng dụng?
- **Độ khó:** ⭐⭐
- **Mã nguồn dẫn chứng:** `lib/presentation/widgets/transaction_form_fields.dart`, `lib/presentation/widgets/log_viewer_components.dart`, `lib/presentation/state/transaction_notifier.dart`.
- **Đáp án ngắn gọn dễ nói:**
  - Nhóm thực hiện refactoring theo quy trình 3 nhóm nhỏ có kiểm chứng liên tục:
    - Nhóm 1: Tách extensions (`category_extension.dart`, `severity_extension.dart`) và tách widget card.
    - Nhóm 2: Chia tách các file UI lớn trên 300 dòng thành các component nhỏ, bảo đảm mọi hàm `build()` dưới 50 dòng.
    - Nhóm 3: Khử code trùng lặp trong Notifier qua hàm `_handleActionFailure()`.
  - Sau mỗi nhóm, nhóm đều chạy `flutter analyze` (đạt 0 warnings) và `flutter test` (bảo đảm toàn bộ 223/223 tests luôn PASS 100%), chứng minh hành vi nghiệp vụ được giữ nguyên vẹn.

---

*Ngân hàng câu hỏi phản biện được hoàn thiện và sẵn sàng cho buổi phỏng vấn thử nghiệm (Giai đoạn 2).*
