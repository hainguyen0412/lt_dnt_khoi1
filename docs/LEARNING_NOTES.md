# TÀI LIỆU HỌC TẬP VÀ PHẢN BIỆN (LEARNING NOTES)

Tài liệu này lưu trữ toàn bộ các khái niệm lập trình hướng đối tượng (OOP), Design Patterns, lý do thiết kế kiến trúc và bộ câu hỏi phản biện bảo vệ đồ án trước hội đồng giảng viên.

---

## BẢNG THEO DÕI ÁP DỤNG MIXIN TRÊN CÁC LỚP THẬT (R3)

| Mixin | Các lớp sử dụng thực tế | Trạng thái hiện tại |
|---|---|---|
| `LoggableMixin` | `FakeRemoteDataSource` (T-107), `LocalDataSource` (T-108), `TransactionRepositoryImpl`, `TransactionProvider` | **Đã áp dụng đủ ở 2 class thật (Data Layer)** ✅ |
| `ValidatableMixin` | `Transaction` (T-103), `TransactionDraft` (T-103) | **Đã áp dụng đủ ở 2 class thật trong Domain** ✅ |
| `TimestampMixin` | `Transaction` (T-103), `TransactionModel` (T-106) | **Đã áp dụng đủ ở 2 class thật (Domain & Data)** ✅ |

---

## T-102: Cây AppException + ExceptionFactory

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Sealed Class (`sealed class AppException`)**:
   - Vị trí: [`lib/core/errors/app_exception.dart`](file:///d:/lt_dnt_khoi1/lib/core/errors/app_exception.dart)
   - Định nghĩa cây phân cấp kế thừa đóng. Toàn bộ các lớp con (`NetworkException`, `RequestTimeoutException`, `ServerException`, `ParseException`, `CacheException`, `ValidationException`, `NotFoundException`, `UnknownException`) đều là `final class` kế thừa trực tiếp từ `AppException` trong cùng file.
2. **Factory Pattern / Factory Constructor (`AppException.from`)**:
   - Vị trí: [`lib/core/errors/app_exception.dart`](file:///d:/lt_dnt_khoi1/lib/core/errors/app_exception.dart) và [`lib/core/errors/exception_factory.dart`](file:///d:/lt_dnt_khoi1/lib/core/errors/exception_factory.dart)
   - `AppException.from` đóng vai trò factory constructor chuyển tiếp, ủy thác logic chuyển đổi lỗi tầng thấp cho `ExceptionFactory.from`.
3. **Encapsulation & Polymorphism (Tính đóng gói và Đa hình)**:
   - Các thuộc tính `message`, `code`, `severity`, `originalError`, `stackTrace` được đóng gói bất biến (`final`).
   - `ServerException` tính toán đa hình mức độ nghiêm trọng (`severity`) động dựa trên `statusCode` (4xx -> warning, 5xx -> error).
4. **Kế thừa và Ghi đè (`toString`)**:
   - Ghi đè `toString()` ở lớp cha để format đồng bộ `${runtimeType}($code): $message`.

### (b) Vì sao thiết kế như vậy?
- **Tại sao dùng `sealed class` thay vì `abstract class` thông thường?**
  - Trong Dart 3.x, `sealed class` tạo ra hệ thống phân cấp đóng (closed hierarchy). Khi dùng `switch (exception)` ở tầng xử lý lỗi hoặc UI, trình biên dịch Dart sẽ bắt buộc phải kiểm tra vét cạn (exhaustive checking). Nếu sau này thêm loại exception mới mà quên xử lý ở switch-case, code sẽ báo lỗi ngay khi compile, loại trừ hoàn toàn nguy cơ lọt bug runtime. Đồng thời, `sealed class` ngăn chặn các package hoặc tầng khác tự tiện kế thừa lung tung bên ngoài thư viện core.
- **Tại sao tách riêng `ExceptionFactory` thay vì viết toàn bộ `switch/case` trong `AppException.from`?**
  - Tuân thủ nguyên lý Trách nhiệm đơn lẻ (Single Responsibility Principle - SRP): `AppException` chỉ có trách nhiệm định nghĩa mô hình dữ liệu của ngoại lệ, còn `ExceptionFactory` chuyên biệt quản lý các quy tắc nghiệp vụ ánh xạ lỗi từ hệ thống và tầng mạng/storage.
- **Tại sao `TypeError` không được map sang `ParseException` tại Factory?**
  - Factory toàn cục không thể biết được ngữ cảnh phát sinh của `TypeError` (nó có thể xuất phát từ lỗi lập trình logic thông thường chứ không phải lỗi parse JSON). Việc ép kiểu sai cấu trúc JSON sẽ được `TransactionModel.fromJson` bắt cục bộ và chủ động bọc thành `ParseException`.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Tại sao các em lại dùng `sealed class` cho `AppException` mà không dùng `abstract class` thông thường hay `implements Exception` đơn giản?*
   - **Đáp án:** Vì `sealed class` trong Dart 3 cho phép thực hiện **exhaustive pattern matching**. Khi viết `switch (exception)`, compiler sẽ ép nhóm phải xử lý đủ tất cả các trường hợp lớp con mà không cần `default`. Nếu sau này mở rộng thêm exception mới, compiler sẽ cảnh báo ngay những nơi chưa xử lý, tránh bỏ sót lỗi runtime.
2. **Câu hỏi 2:** *Tại sao tầng Data lại ném ra `HttpStatusError` và `CacheStorageError` mà không ném thẳng `ServerException` hay `CacheException`?*
   - **Đáp án:** Để tuân thủ việc tách biệt mối quan tâm (Separation of Concerns). DataSource chỉ biết giao thức mạng hoặc disk I/O tầng thấp và ném lỗi thô (raw error). Tầng Repository sẽ dùng `ExceptionFactory` (Factory Pattern) để chuẩn hóa các lỗi thô này thành `AppException` thống nhất, giúp tầng Domain và Presentation hoàn toàn độc lập với các thư viện mạng/lưu trữ cụ thể.
3. **Câu hỏi 3:** *Trường `originalError` và `stackTrace` trong `AppException` được giữ lại để làm gì khi đã có `message`?*
   - **Đáp án:** `message` là mô tả tóm tắt kỹ thuật, còn `originalError` và `stackTrace` giữ lại đối tượng lỗi gốc và vết ngăn xếp ban đầu. Điều này cực kỳ quan trọng cho `ErrorLogger` và Centralized Error Handling Pipeline ở các ticket sau để ghi vết chính xác vị trí phát sinh lỗi ban đầu, phục vụ gỡ lỗi mà không làm biến mất dấu vết của ngoại lệ gốc.

---

## T-101: Result<T> (Functional Error Handling)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Generic Programming (`sealed class Result<T>`)**:
   - Vị trí: [`lib/core/utils/result.dart`](file:///d:/lt_dnt_khoi1/lib/core/utils/result.dart)
   - Cho phép tái sử dụng cấu trúc kết quả cho bất kỳ kiểu dữ liệu nào (`Result<Transaction>`, `Result<List<Transaction>>`, `Result<Summary>`, `Result<void>`).
2. **Sealed Class Hierarchy (`Success<T>` & `Failure<T>`)**:
   - Hai lớp con cụ thể kế thừa `Result<T>`: `Success<T>` chứa `final T data`, `Failure<T>` chứa `final AppException error`.
3. **Polymorphism via Method Dispatch (Đa hình phương thức)**:
   - Các phương thức `fold`, `map`, `getOrElse`, `isSuccess` được khai báo trừu tượng trên `Result<T>` và được cài đặt đa hình cụ thể trên từng lớp con `Success` và `Failure`, không cần kiểm tra `if-else` kiểu thủ công.
4. **Value Equality (Toán tử bằng giá trị)**:
   - Cài đặt `operator ==` và `hashCode` dựa trên dữ liệu bên trong của `Success` và `Failure`.

### (b) Vì sao thiết kế như vậy?
- **Tại sao dùng `Result<T>` thay vì ném (throw) Exception ra ngoài hàm?**
  - Trong lập trình di động, các thao tác I/O (gọi API, đọc cache) luôn có khả năng thất bại. Ném Exception làm luồng thực thi bị ngắt quãng đột ngột (uncontrolled jump) và nếu UI quên `try-catch` thì ứng dụng sẽ crash. Dùng `Result<T>` (mô hình Either Monad trong Functional Programming kết hợp OOP) biến lỗi thành một giá trị kiểu dữ liệu tường minh (explicit return type). Bất kỳ ai gọi Repository đều buộc phải xử lý cả 2 tình huống: thành công và thất bại.
- **Tại sao viết phương thức trực tiếp trên class mà KHÔNG dùng Extension Method?**
  - Giữ vững tính đóng gói (Encapsulation) của OOP; các phương thức cốt lõi tận dụng cơ chế đa hình trực tiếp (dynamic dispatch) trên 2 subclass; IDE tự động gợi ý (auto-completion) ngay lập tức mà không cần import thêm file extension; code tường minh, trực quan, dễ bảo vệ đồ án.
- **Tại sao `Failure` trong `Result<T>` chỉ chứa `AppException` mà không phải `Object`?**
  - Khóa chặt hợp đồng kỹ thuật: toàn bộ lỗi trong hệ thống bắt buộc phải được chuẩn hóa về cây `AppException` trước khi gói vào `Result`. Không cho phép trả về lỗi thô chưa được phân loại lên tầng trên.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Cơ chế `Result<T>` này khác gì so với việc dùng `try-catch` truyền thống ở mọi nơi?*
   - **Đáp án:** `try-catch` truyền thống dễ bị bỏ sót ở tầng UI dẫn đến crash ứng dụng, và chữ ký hàm `Future<Transaction>` không thể hiện cho lập trình viên biết nó có thể ném ra lỗi gì. `Future<Result<Transaction>>` thể hiện rõ trong type signature rằng thao tác này có thể thất bại, buộc caller phải gọi `fold` hoặc `switch` để xử lý cả hai trường hợp.
2. **Câu hỏi 2:** *Khi thực hiện xóa một bản ghi (`delete`), không có dữ liệu nào trả về thì `Result<T>` xử lý như thế nào?*
   - **Đáp án:** Nhờ tính linh hoạt của Generics trong Dart, kiểu dữ liệu trả về sẽ là `Result<void>`. Khi xóa thành công, ta trả về `Success(null)` (hoặc `Success<void>(null)`), và khi thất bại trả về `Failure(error)`. Tầng UI vẫn kiểm tra được `result.isSuccess` bình thường.
3. **Câu hỏi 3:** *Phương thức `map` trên `Failure<T>` hoạt động ra sao và tại sao không gọi hàm `transform`?*
   - **Đáp án:** Khi một `Result` là `Failure`, nghĩa là không hề có `data` kiểu `T` để biến đổi. Vì vậy `map` trên `Failure` sẽ bỏ qua hàm `transform` và trả về ngay một `Failure<R>` mới với đúng đối tượng `error` gốc được giữ nguyên (`identical`), giúp chuỗi xử lý lan truyền lỗi an toàn mà không làm mất thông tin ngoại lệ.

---

## T-104: Mixins (LoggableMixin, ValidatableMixin, TimestampMixin)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Mixin Composition (Đa kế thừa hành vi - Behavioral Reuse)**:
   - Dart không hỗ trợ đa kế thừa lớp (`multiple class inheritance`) để tránh vấn đề xung đột hình thoi (Diamond Problem). Thay vào đó, Dart cung cấp `mixin` để tái sử dụng mã nguồn và hành vi trên nhiều nhánh phân cấp lớp hoàn toàn độc lập mà không cần quan hệ cha-con cứng nhắc.
2. **Khai báo Trừu tượng kết hợp Cài đặt Cụ thể trong Mixin**:
   - [`lib/core/utils/validatable_mixin.dart`](file:///d:/lt_dnt_khoi1/lib/core/utils/validatable_mixin.dart): Yêu cầu lớp áp dụng mixin phải cung cấp hàm trừu tượng `validate()`, đồng thời mixin cung cấp sẵn các thuộc tính cụ thể `isValid`, `firstError` và phương thức `ensureValid() -> Result<void>`.
   - [`lib/core/utils/timestamp_mixin.dart`](file:///d:/lt_dnt_khoi1/lib/core/utils/timestamp_mixin.dart): Yêu cầu `createdAt`, `updatedAt` trừu tượng, cung cấp sẵn `lastModified` và `isNewerThan()`.
3. **Tránh phụ thuộc vòng (Circular Dependency Inversion)**:
   - [`lib/core/utils/loggable_mixin.dart`](file:///d:/lt_dnt_khoi1/lib/core/utils/loggable_mixin.dart): Sử dụng trực tiếp `dart:developer log()` với `logTag` mặc định lấy từ `runtimeType`. Mixin này không phụ thuộc vào `ErrorLogger` ở tầng trên, đảm bảo tính độc lập tối đa của tầng tiện ích dùng chung.

### (b) Vì sao thiết kế như vậy?
- **Tại sao dùng Mixin thay vì tạo một BaseClass chung như `BaseEntity`?**
  - Nếu dùng kế thừa lớp cha `class Transaction extends BaseEntity`, ta sẽ khóa chặt phân cấp kế thừa của Dart (vốn là đơn kế thừa). Sau này nếu `TransactionModel` cần kế thừa từ một lớp khác của thư viện bên ngoài hoặc muốn tái sử dụng các hành vi khác, ta sẽ bị bế tắc. Mixin cho phép lớp tự do ghép nối (compose) nhiều khả năng: `class Transaction with TimestampMixin, ValidatableMixin`.
- **Tại sao `ensureValid()` lại trả về `Result<void>` thay vì ném ngoại lệ?**
  - Giúp tích hợp mượt mà với mô hình Functional Error Handling đã thiết kế ở T-101 (`Result<T>`). Khi kiểm tra dữ liệu ở UseCase hoặc Repository, ta có thể viết `final validRes = draft.ensureValid(); if (validRes.isFailure) return validRes;` một cách rất thanh thoát mà không cần bọc khối `try-catch`.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Sự khác nhau cơ bản giữa `mixin` và `abstract class` (interface) trong Dart là gì?*
   - **Đáp án:** `abstract class` chủ yếu định nghĩa giao ước (contract) các phương thức mà lớp con bắt buộc phải cài đặt lại, trong khi `mixin` cho phép chia sẻ trực tiếp các dòng mã cài đặt cụ thể (concrete implementation) mà không tạo ra quan hệ cha - con trong cây phả hệ, tránh được vấn đề Diamond Problem của đa kế thừa.
2. **Câu hỏi 2:** *Tại sao trong `ValidatableMixin` lại có cả `validate()` lẫn `ensureValid()`?*
   - **Đáp án:** `validate()` trả về danh sách đầy đủ tất cả các lỗi vi phạm `List<ValidationException>`, rất hữu ích khi tầng Presentation/Form cần hiển thị lỗi đỏ đồng thời dưới nhiều trường nhập liệu khác nhau. Còn `ensureValid()` chuyển đổi lỗi thành `Result<void>` chứa `firstError`, phục vụ các UseCase cần ngắt luồng xử lý ngay khi gặp lỗi đầu tiên.
3. **Câu hỏi 3:** *Nếu một class sử dụng `LoggableMixin` muốn đổi tên tag hiển thị trên log console thì làm thế nào?*
   - **Đáp án:** Chỉ cần ghi đè (override) getter `String get logTag => 'MyCustomTag';` trong class đó. Mixin đã khai báo `String get logTag => runtimeType.toString();` như một getter mở, cho phép lớp thực thi tùy biến bất cứ lúc nào.

---

## T-103: Domain Entities & Validation Rules

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Value Object Pattern (`Money`)**:
   - Vị trí: [`lib/domain/entities/money.dart`](file:///d:/lt_dnt_khoi1/lib/domain/entities/money.dart)
   - Đối tượng giá trị đại diện cho số tiền VND. Không có danh tính (identity), hai đối tượng có cùng `amount` thì bằng nhau về giá trị (`operator ==`). Bất biến (`immutable`), tự đóng gói các phép tính toán tài chính (`+`, `-`, `compareTo`).
2. **Named Constructors (R1)**:
   - `Money.zero()`: Khởi tạo giá trị 0 đồng tường minh.
   - `Transaction.income(...)`: Khởi tạo giao dịch thu nhập.
   - `Transaction.expense(...)`: Khởi tạo giao dịch chi tiêu.
   - Tăng tính biểu cảm (expressiveness) của ngôn ngữ, loại bỏ các cờ boolean mơ hồ (ví dụ: tránh dùng `Transaction(isIncome: true)`).
3. **Immutable Entity & CopyWith Pattern**:
   - Vị trí: [`lib/domain/entities/transaction.dart`](file:///d:/lt_dnt_khoi1/lib/domain/entities/transaction.dart)
   - Tất cả các trường đều là `final`. Khi cần chỉnh sửa thông tin, gọi phương thức `copyWith()` tạo một bản sao mới với trạng thái cập nhật, bảo vệ tính toàn vẹn của dữ liệu trong bộ nhớ.
4. **Kiến trúc Domain thuần khiết (R5 - Pure Domain Layer)**:
   - Toàn bộ thư mục `lib/domain/` tuyệt đối chỉ import thư viện chuẩn `dart:*` và các lớp core (`AppException`, `Result`, mixins). Hoàn toàn không import bất kỳ package nào từ Flutter, tầng Data hay bên ngoài.
5. **Specification / Rule Engine Pattern (`TransactionRules`)**:
   - Vị trí: [`lib/domain/validation/transaction_rules.dart`](file:///d:/lt_dnt_khoi1/lib/domain/validation/transaction_rules.dart)
   - Đóng gói các quy tắc nghiệp vụ thành các hàm thuần (Pure Functions). Cả `Transaction` và `TransactionDraft` đều tái sử dụng chung bộ quy tắc này (DRY), kiểm soát thứ tự thẩm định cố định: `title` -> `amount` -> `date`.

### (b) Vì sao thiết kế như vậy?
- **Tại sao dùng `int` cho `Money` mà tuyệt đối không dùng `double`?**
  - Trong lập trình tài chính, kiểu số thực `double` (chuẩn IEEE 754) luôn có rủi ro sai số làm tròn số học nhị phân (ví dụ: `0.1 + 0.2 = 0.30000000000000004`). Đồng Việt Nam (VND) không có đơn vị xu hào lẻ sau dấu phẩy. Sử dụng số nguyên `int` lưu trữ đồng giúp phép toán cộng, trừ, tính tổng luôn đạt độ chính xác tuyệt đối 100%.
- **Tại sao constructor `Money(this.amount)` lại chấp nhận số âm mà không ném exception?**
  - Để phân tách rõ ràng giữa việc *biểu diễn dữ liệu* và *kiểm tra quy tắc nghiệp vụ*. Khi người dùng nhập sai số tiền âm trên bàn phím, UI truyền số đó vào `TransactionDraft(amount: Money(-1000))`. Tầng Validation sẽ phát hiện lỗi và trả về `ValidationException` hiển thị thông báo nhẹ nhàng cho người dùng sửa lại. Nếu ném Exception ngay trong constructor của `Money`, ứng dụng có thể bị crash trước khi dữ liệu kịp được kiểm tra. Ngoài ra, số dư tài chính (`balance = thu - chi`) hoàn toàn có thể mang giá trị âm khi chi vượt quá thu.
- **Tại sao phải tạo riêng `TransactionDraft` mà không dùng luôn `Transaction`?**
  - Khi người dùng đang mở màn hình tạo mới giao dịch trên form, giao dịch đó chưa hề có `id` (do tầng data sinh) và chưa có `createdAt`. Nếu dùng chung `Transaction`, lập trình viên sẽ buộc phải truyền các giá trị giả rác (dummy values như `id: ''`, `createdAt: DateTime.now()`) vào đối tượng, vi phạm tính toàn vẹn của Entity. Tách `TransactionDraft` giúp phản ánh chính xác trạng thái nhập liệu tạm thời của người dùng.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Tại sao tầng Domain của các em lại không được import Flutter (`package:flutter`)?*
   - **Đáp án:** Theo nguyên lý Clean Architecture, Domain là tầng lõi (Core Business Layer) chứa các quy tắc nghiệp vụ quan trọng nhất của doanh nghiệp. Nó phải độc lập với framework hiển thị (UI framework). Việc không import Flutter giúp logic nghiệp vụ có thể chạy trên CLI, Backend Dart (Server-side), hoặc dễ dàng viết Unit Test chạy cực nhanh mà không cần khởi động môi trường máy ảo đồ họa Flutter Test Engine.
2. **Câu hỏi 2:** *Tại sao trong `Transaction` các em lại tự viết tay `operator ==` và `hashCode` mà không dùng package phổ biến như `Equatable`?*
   - **Đáp án:** Nhóm tuân thủ đúng yêu cầu của đề bài là hiểu sâu sắc bản chất OOP trong Dart. Việc tự viết `operator ==` và `hashCode` sử dụng `Object.hash()` giúp sinh viên nắm vững cơ chế so sánh giá trị (value equality) của ngôn ngữ, đồng thời giảm thiểu tối đa sự phụ thuộc vào các thư viện bên ngoài (Zero Dependency), giúp source code nhẹ và hoàn toàn tự chủ.
3. **Câu hỏi 3:** *Hàm `TransactionRules.validate` nhận tham số `DateTime? now` để làm gì?*
   - **Đáp án:** Để phục vụ kỹ thuật kiểm thử độc lập (Testability/Dependency Injection mốc thời gian). Quy tắc ngày giao dịch không được sau `now + 1 ngày`. Nếu gọi cứng `DateTime.now()` bên trong hàm, khi viết Unit Test vào các thời điểm giao thừa hoặc múi giờ khác nhau, test có thể bị chập chờn (flaky test). Việc cho phép truyền `now` vào giúp test fixture kiểm soát chính xác 100% các mốc ngày biên (boundary dates) mà không phụ thuộc vào đồng hồ hệ thống.

---

## T-105: Repository Interface + Use Cases

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Repository Pattern (Interface Segregation & Dependency Inversion)**:
   - Vị trí: [`lib/domain/repositories/transaction_repository.dart`](file:///d:/lt_dnt_khoi1/lib/domain/repositories/transaction_repository.dart)
   - Khai báo `abstract interface class TransactionRepository` (từ khóa `interface class` mới trong Dart 3.x ngăn việc kế thừa tùy tiện từ package ngoài mà ép buộc phải implement).
   - Đóng vai trò lớp trung gian che giấu toàn bộ chi tiết lưu trữ (Database, REST API, SharedPreferences) khỏi tầng Domain và Use Cases.
2. **Command Pattern / Callable Classes (Use Cases)**:
   - Vị trí: `lib/domain/usecases/` ([`GetTransactions`](file:///d:/lt_dnt_khoi1/lib/domain/usecases/get_transactions.dart), [`GetTransactionById`](file:///d:/lt_dnt_khoi1/lib/domain/usecases/get_transaction_by_id.dart), [`AddTransaction`](file:///d:/lt_dnt_khoi1/lib/domain/usecases/add_transaction.dart), [`UpdateTransaction`](file:///d:/lt_dnt_khoi1/lib/domain/usecases/update_transaction.dart), [`DeleteTransaction`](file:///d:/lt_dnt_khoi1/lib/domain/usecases/delete_transaction.dart), [`GetSummary`](file:///d:/lt_dnt_khoi1/lib/domain/usecases/get_summary.dart)).
   - Mỗi use case là một class chuyên biệt chịu trách nhiệm cho đúng 1 hành vi nghiệp vụ duy nhất (Single Responsibility Principle).
   - Triển khai phương thức `call()` biến instance thành callable object, gọi trực tiếp như hàm `addTransaction(draft)`.
3. **Dependency Injection (Constructor Injection)**:
   - Tất cả các Use Case đều nhận `TransactionRepository` và các hàm phụ thuộc (`idGenerator`, `clock`) qua constructor.
   - Giúp việc kiểm thử với `mocktail` đạt 100% độc lập, không dính líu đến thời gian thật hay I/O thật.
4. **Hợp đồng Nghiệp vụ Không Ném Ngoại Lệ (No-Throw Exception Contract)**:
   - Tất cả phương thức trả về `Future<Result<T>>`. Lỗi được coi là giá trị (error as value) thay vì ngắt luồng bằng exception.

### (b) Vì sao thiết kế như vậy?
- **Tại sao `ValidationException` chỉ có một `field` và khi có nhiều lỗi validation thì trả lỗi ĐẦU TIÊN theo thứ tự `title` -> `amount` -> `date`?**
  - **Quyết định thiết kế:**
    1. Trải nghiệm người dùng (UX) trên màn hình di động: Bàn phím ảo và không gian màn hình nhỏ khiến người dùng chỉ có thể tập trung sửa từng lỗi một từ trên xuống dưới. Trả về lỗi vi phạm đầu tiên giúp giao diện focus ngay vào ô nhập liệu lỗi cao nhất (tiêu đề, rồi đến số tiền, rồi đến ngày).
    2. Đơn giản hóa mô hình dữ liệu (Simplicity): Hợp đồng `ValidationException(String? field, ...)` giữ cho cây exception gọn gàng, không cần tạo thêm cấu trúc phức tạp như `Map<String, String>` hay `List<ValidationError>` trong exception, giúp sinh viên dễ giải thích và bảo vệ đồ án.
- **Tại sao Use Case kiểm tra validation trước khi gọi Repository?**
  - Áp dụng nguyên lý "Fail-Fast": Nếu dữ liệu đầu vào không hợp lệ, không có lý do gì phải tiêu tốn tài nguyên mạng (Network request) hoặc I/O ổ đĩa (Disk write). Việc chặn ngay tại Use Case giúp bảo vệ tầng Data và đảm bảo dữ liệu gửi xuống Repository luôn toàn vẹn.
- **Tại sao `AddTransaction` và `UpdateTransaction` lại nhận hàm `clock` và `idGenerator` trong constructor?**
  - Tránh phụ thuộc cứng vào `DateTime.now()` và bộ sinh ID ngẫu nhiên. Khi viết Unit Test, ta có thể tiêm `clock: () => fixedDate` và `idGenerator: () => 'fixed-id'` để kiểm tra chính xác giá trị gán vào entity mà không sợ sai lệch mili-giây.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Tại sao trong Clean Architecture các em lại cần tầng Use Case (Domain) nằm giữa Presentation và Repository, mà không cho ViewModel/Provider gọi thẳng Repository?*
   - **Đáp án:** Vì Repository chỉ đảm nhiệm việc đọc/ghi dữ liệu thuần túy (CRUD). Tầng Use Case đóng gói các quy tắc nghiệp vụ điều phối (Business Workflow Orchestration) độc lập với giao diện — ví dụ: tự động sinh ID, gán mốc thời gian tạo/sửa (`createdAt`, `updatedAt`), thẩm định dữ liệu đầu vào (Validation Fail-Fast) trước khi ghi xuống. Nếu gọi thẳng Repository từ UI, các logic nghiệp vụ này sẽ bị rò rỉ (leak) lên tầng giao diện và bị lặp lại nếu có nhiều màn hình cùng gọi.
2. **Câu hỏi 2:** *Từ khóa `abstract interface class` trong Dart 3 khác gì so với `abstract class` truyền thống?*
   - **Đáp án:** Trong Dart 3, `interface class` cho phép lớp được triển khai (`implements`) nhưng **ngăn cấm không cho kế thừa (`extends`)** từ các thư viện/file bên ngoài. Kết hợp `abstract interface class` tạo ra một giao diện thuần túy (Pure Interface) đúng chuẩn OOP, ép buộc các lớp cài đặt (như `TransactionRepositoryImpl`) phải tự triển khai toàn bộ các phương thức mà không được thừa hưởng mã nguồn mặc định, tăng tính tường minh của kiến trúc.
3. **Câu hỏi 3:** *Tại sao các Use Case lại sử dụng phương thức `call()` mà không đặt tên phương thức là `execute()` hay `run()`?*
   - **Đáp án:** Phương thức `call()` là một tính năng đặc biệt của ngôn ngữ Dart (Callable Class). Khi một class có hàm `call()`, ta có thể gọi đối tượng đó y như gọi một hàm: `final result = await addTransaction(draft);`. Cách viết này vừa đảm bảo tính hướng đối tượng (class có trạng thái và dependency được tiêm qua constructor), vừa mang lại cú pháp ngắn gọn, trực quan như phong cách lập trình hàm (Functional Programming).

---

## T-106: TransactionModel (DTO) & Data Mapping

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Data Transfer Object (DTO) Pattern**:
   - Vị trí: [`lib/data/models/transaction_model.dart`](file:///d:/lt_dnt_khoi1/lib/data/models/transaction_model.dart)
   - Đóng gói dữ liệu ở định dạng nguyên thủy (primitive types: `int`, `String`, ISO-8601 string) để tối ưu hóa việc truyền tải và lưu trữ (JSON serialization/deserialization) qua tầng Data.
2. **Factory Pattern / Data Mapper Pattern**:
   - `TransactionModel.fromJson(Object? json)`: Factory constructor phân tích và chuyển đổi dữ liệu thô từ mạng/storage thành đối tượng an toàn.
   - `TransactionModel.fromEntity(Transaction)` và `toEntity()`: Đóng vai trò Data Mapper hai chiều, chuyển đổi giữa tầng Data Model và Domain Entity mà không làm Domain bị rò rỉ chi tiết cấu trúc JSON.
3. **Mixin Reuse (R3 - Đạt chuẩn 2 class thật)**:
   - `TransactionModel with TimestampMixin`: Kế thừa hành vi so sánh mốc sửa đổi (`lastModified`, `isNewerThan`) tương tự như `Transaction`, hoàn thành trọn vẹn chỉ tiêu sử dụng `TimestampMixin` ở >= 2 class thật.
4. **Phòng vệ Ngoại lệ (Defensive Exception Wrapping)**:
   - Bọc toàn bộ quá trình parse trong `try-catch` để đảm bảo KHÔNG BAO GIỜ để lọt lỗi thô (`TypeError`, `CastError`, `FormatException`) ra ngoài, mà luôn bọc thành `ParseException` chỉ rõ tên trường bị lỗi.

### (b) Vì sao thiết kế như vậy?
- **Tại sao Model KHÔNG kiểm tra quy tắc nghiệp vụ (ví dụ: số tiền > 0, ngày không quá xa tương lai)?**
  - **Ranh giới kiến trúc rõ ràng (Separation of Concerns):**
    - `TransactionModel` chỉ chịu trách nhiệm **Schema Validation** (kiểm tra tính toàn vẹn của dữ liệu dạng thô): JSON có phải Map không, có đủ các trường bắt buộc không, kiểu dữ liệu có đúng là `int` (VND) không, chuỗi ngày có đúng chuẩn ISO-8601 không, category có nằm trong danh mục hệ thống hiểu được không.
    - Còn việc số tiền có được phép âm không, ngày có quá tương lai không là **Business Rules Validation** thuộc quyền quyết định của tầng Domain (`TransactionRules`). Nếu tầng Model tự ý chặn số tiền âm, hệ thống sẽ crash/báo lỗi ParseException trước khi tầng Domain có cơ hội xử lý trả về `ValidationException` có hướng dẫn cụ thể cho người dùng.
- **Tại sao chuyển đổi Enum <-> String viết thành hàm riêng và KHÔNG dùng `enum.index`?**
  - Dùng số nguyên `index` (0, 1, 2...) khi serialize JSON cực kỳ nguy hiểm. Nếu sau này nhóm thêm danh mục mới vào giữa enum hoặc sắp xếp lại thứ tự các enum trong code, dữ liệu cũ đã lưu trên đĩa hoặc server sẽ bị ánh xạ sai hoàn toàn (ví dụ: `food` biến thành `transport`). Dùng chuỗi định danh `enum.name` (`'food'`, `'transport'`) đảm bảo tính tương thích xuôi và ngược (Backward/Forward Compatibility) tuyệt đối.
- **Tại sao `TypeError` lại được bọc thành `ParseException` tại đây?**
  - Như đã ghi chú ở T-102, `ExceptionFactory` toàn cục không biết ngữ cảnh của `TypeError`. Nhưng tại `TransactionModel.fromJson`, ta biết đích xác lỗi ép kiểu xuất phát từ dữ liệu JSON đầu vào không đúng schema mong đợi (ví dụ: API trả về chuỗi thay vì số nguyên). Vì vậy, Model chủ động bắt `TypeError` và bọc thành `ParseException` kèm thông tin chi tiết để tầng pipeline ghi log chính xác.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Tại sao các em không dùng luôn `Transaction` để lưu/đọc JSON mà phải tạo thêm lớp `TransactionModel` làm tăng số lượng file?*
   - **Đáp án:** Để tuân thủ nguyên lý Clean Architecture và tách biệt mối quan tâm (Separation of Concerns). `Transaction` thuộc tầng Domain, chứa các đối tượng nghiệp vụ giàu ý nghĩa (`Money`, `Category` enum) và không nên biết gì về cách serialize JSON hay cấu trúc lưu trữ của cơ sở dữ liệu. `TransactionModel` thuộc tầng Data, đóng vai trò DTO/Adapter làm cầu nối dịch dữ liệu thô (JSON Map) sang Entity và ngược lại. Nếu sau này cấu trúc API hoặc tên trường JSON đổi (ví dụ: `amount` đổi thành `total_amount`), ta chỉ cần sửa `TransactionModel` mà không làm ảnh hưởng đến tầng Domain hay UI.
2. **Câu hỏi 2:** *Tại sao các em không dùng package `json_serializable` hay `freezed` sinh code tự động cho nhanh?*
   - **Đáp án:** Nhóm tuân thủ chặt chẽ đề bài: nắm vững bản chất OOP và cơ chế xử lý ngoại lệ trong Dart. Việc tự viết tay `fromJson` cho phép nhóm kiểm soát 100% việc xử lý lỗi (chặn `TypeError`, kiểm tra số nguyên đồng VND không có phần thập phân, kiểm tra enum hợp lệ) và bọc thành `ParseException` chỉ rõ tên trường vi phạm, điều mà các package tự sinh code không làm chi tiết và chặt chẽ theo đúng yêu cầu đề bài được.
3. **Câu hỏi 3:** *Nếu dữ liệu JSON trên server trả về trường `amount` là `50000.5` thì `TransactionModel.fromJson` sẽ xử lý thế nào và vì sao?*
   - **Đáp án:** Phương thức `fromJson` kiểm tra `rawAmount is double && rawAmount % 1 != 0` và sẽ lập tức ném ra `ParseException` với thông báo `'Invalid field [amount]: must be an integer (VND), got 50000.5'`. Lý do là tiền tệ Việt Nam Đồng (VND) theo đề bài bắt buộc phải lưu số nguyên đồng, không chấp nhận số lẻ thập phân; việc chặn ngay từ tầng Model giúp bảo vệ tính toàn vẹn của dữ liệu trước khi đi vào hệ thống.

---

## T-107 & T-108: DataSources, FakeRemoteDataSource & LocalDataSource (Cache)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Generic Interface (`DataSource<T>` & `CacheDataSource<T>`) (R4)**:
   - Vị trí: [`lib/data/datasources/data_source.dart`](file:///d:/lt_dnt_khoi1/lib/data/datasources/data_source.dart)
   - Sử dụng Generics `T` để chuẩn hóa các thao tác truy xuất dữ liệu CRUD cơ sở cho mọi thực thể.
   - Áp dụng nguyên lý Interface Segregation (ISP): `CacheDataSource<T>` kế thừa `DataSource<T>` để bổ sung riêng phương thức `replaceAll(List<T> items)` cho nguồn dữ liệu bộ nhớ đệm mà không làm phình interface của các nguồn dữ liệu chỉ đọc/ghi đơn lẻ.
2. **Data Source Pattern (Tách biệt Remote và Local)**:
   - Vị trí:
     - Remote: [`lib/data/datasources/fake_remote_data_source.dart`](file:///d:/lt_dnt_khoi1/lib/data/datasources/fake_remote_data_source.dart)
     - Local Cache: [`lib/data/datasources/local_data_source.dart`](file:///d:/lt_dnt_khoi1/lib/data/datasources/local_data_source.dart)
   - Tách biệt hoàn toàn nguồn dữ liệu mạng và nguồn dữ liệu cục bộ, mở đường cho tầng Repository điều phối chiến lược offline-first (Offline Caching Strategy).
3. **Failure Simulation Pattern (`FailureSimulator`)**:
   - Vị trí: [`lib/core/simulation/failure_mode.dart`](file:///d:/lt_dnt_khoi1/lib/core/simulation/failure_mode.dart)
   - Kế thừa `ChangeNotifier` để quản lý trạng thái giả lập các loại lỗi kết nối mạng/máy chủ. Cho phép tầng Presentation (UI Debug Panel) điều khiển trực tiếp mà không cần phụ thuộc vào tầng Data.
4. **Mixin Composition (R3 - Đạt chuẩn 2 class thật)**:
   - Cả `FakeRemoteDataSource` và `LocalDataSource` đều sử dụng `with LoggableMixin` để tự động ghi log vết truy vấn, chính thức hoàn thành yêu cầu R3 cho cả 3 mixin của đề bài (`ValidatableMixin`, `TimestampMixin`, `LoggableMixin`).

### (b) Vì sao thiết kế như vậy?
- **Tại sao DataSource NÉM LỖI THÔ (Raw Exceptions) mà KHÔNG trả về `Result<T>`?**
  - **Phân định ranh giới trách nhiệm (Separation of Concerns):**
    - DataSource là tầng tiếp xúc trực tiếp với hạ tầng vật lý (Network Socket, HTTP Transport, Local Disk Storage). Khi gặp sự cố, nó ném các ngoại lệ nguyên thủy đúng bản chất kỹ thuật: `SocketException`, `TimeoutException`, `HttpStatusError(500)`, `CacheStorageError`.
    - Trách nhiệm của tầng Repository (`TransactionRepositoryImpl`) là bắt (catch) các lỗi thô này, sử dụng `ExceptionFactory` (Factory Pattern) để chuẩn hóa thành `AppException`, và gói vào `Result<T>` an toàn. Nếu để DataSource tự trả về `Result<T>`, ta sẽ làm lặp lại code xử lý lỗi ở mọi DataSource và phá vỡ vai trò điều phối trung tâm của Repository.
- **Tại sao chọn `SharedPreferences` thay vì `sqflite` cho `LocalDataSource`?**
  - **Đơn giản, đúng mục tiêu bài tập lớn (YAGNI & KISS):**
    1. Dữ liệu của ứng dụng Sổ chi tiêu cá nhân demo có quy mô vừa và nhỏ (dưới vài ngàn giao dịch), việc lưu toàn bộ danh sách được tuần tự hóa JSON vào một khóa `cached_transactions_v1` trong `SharedPreferences` đạt tốc độ đọc/ghi cực nhanh trên bộ nhớ RAM.
    2. `SharedPreferences` không yêu cầu biên dịch thư viện C++ native phức tạp như `sqflite`, giúp ứng dụng chạy được trên mọi nền tảng (Android, iOS, Web, Windows/macOS Desktop) và chạy trơn tru trong môi trường kiểm thử Unit Test (`SharedPreferences.setMockInitialValues`) mà không bao giờ gặp lỗi thiếu driver SQLite.
- **Tại sao mọi lỗi trong `LocalDataSource` đều được bọc thành `CacheStorageError`?**
  - Đóng gói lỗi tầng thấp: Khi đọc SharedPreferences, có thể phát sinh lỗi JSON hỏng (`FormatException`) hoặc lỗi sai kiểu dữ liệu (`TypeError`). `LocalDataSource` bắt toàn bộ các lỗi này và bọc lại thành `CacheStorageError(message, cause)`, giúp tầng Repository dễ dàng nhận biết đó là sự cố đọc/ghi bộ nhớ đệm cục bộ mà không cần phải `catch` riêng từng ngoại lệ của thư viện `dart:convert`.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Tại sao các em lại ném ngoại lệ (`throw`) ở DataSource trong khi ở tầng Repository các em cam kết "không bao giờ ném Exception"?*
   - **Đáp án:** Vì mỗi tầng kiến trúc có một giao ước (Contract) riêng. DataSource nằm ở tầng biên tiếp xúc với Driver mạng/ổ đĩa nên sử dụng cơ chế ngoại lệ truyền thống của ngôn ngữ Dart để báo hiệu sự cố I/O. Còn Repository là ranh giới giữa Data và Domain, nó chịu trách nhiệm bắt tất cả các ngoại lệ thô từ các DataSource, biến đổi thành `Result.failure(AppException)` để tầng Domain và UI xử lý an toàn theo phong cách Functional Error Handling mà không lo crash app.
2. **Câu hỏi 2:** *Lớp `FailureSimulator` được tạo ra để làm gì và tại sao lại dùng `ChangeNotifier`?*
   - **Đáp án:** `FailureSimulator` phục vụ mục đích kiểm thử và demo trực tiếp cho hội đồng giảng viên. Thay vì phải tắt wifi thật hoặc dựng một server lỗi 500 phức tạp, nhóm cung cấp `FailureSimulator` để giả lập tức thì các lỗi: rớt mạng (`SocketException`), timeout (`TimeoutException`), server sập (`HttpStatusError 500`), hoặc dữ liệu lỗi (`ParseException`). Dùng `ChangeNotifier` giúp tầng giao diện (Settings/Debug Panel) có thể gắn vào `Provider` để bật/tắt các chế độ lỗi và cập nhật UI ngay lập tức.
3. **Câu hỏi 3:** *Phương thức `replaceAll` trong `CacheDataSource` phục vụ trường hợp nghiệp vụ nào?*
   - **Đáp án:** Khi ứng dụng khởi động hoặc khi người dùng vuốt làm mới (pull-to-refresh), Repository sẽ tải toàn bộ danh sách giao dịch mới nhất từ Remote Server về. Phương thức `replaceAll` cho phép ghi đè một lần duy nhất toàn bộ danh sách này vào bộ nhớ đệm cục bộ, đảm bảo dữ liệu trong Cache luôn đồng bộ hoàn toàn với Remote mà không cần phải thực hiện từng lệnh add/update lẻ tẻ gây nghẽn I/O.

---

## T-201: TransactionRepositoryImpl & Offline Fallback Pipeline

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Repository Pattern (Hiện thực hóa Domain Interface) (R6)**:
   - Vị trí: [`lib/data/repositories/transaction_repository_impl.dart`](file:///d:/lt_dnt_khoi1/lib/data/repositories/transaction_repository_impl.dart)
   - Hiện thực hóa giao diện trừu tượng `TransactionRepository` (từ Domain). Đóng gói và điều phối giữa hai nguồn dữ liệu `remoteDataSource` và `localDataSource`.
2. **Factory Pattern Integration (R7)**:
   - Sử dụng `AppException.from(error, stackTrace)` (Factory Pattern) để tự động nhận diện và chuẩn hóa mọi lỗi thô tầng thấp (`SocketException`, `HttpStatusError`, `CacheStorageError`, `StateError`...) thành cây `AppException`.
   - Sử dụng Data Mapper của `TransactionModel` (`fromEntity`, `toEntity`) để dịch chuyển dữ liệu hai chiều giữa Data Model và Domain Entity.
3. **Cơ chế try-catch-finally Nâng cao (R8)**:
   - Sử dụng cấu trúc `try-catch-finally` ở tất cả các phương thức public của Repository.
   - Khối `finally` đảm bảo luôn luôn thực thi dù tác vụ thành công hay bắt lỗi, phục vụ mục đích thực tế: dừng `Stopwatch` và ghi log thời lượng benchmark bằng `LoggableMixin`.
4. **Offline Caching & Fallback Strategy**:
   - Hàm thẩm định `_shouldFallbackToCache(AppException)`: Chỉ rơi về cache khi gặp sự cố mạng hoặc máy chủ (`NetworkException`, `RequestTimeoutException`, `ServerException` >= 500, `ParseException`).
   - Chặn đứng không rơi về cache khi gặp lỗi client/nghiệp vụ (`NotFoundException`, `ServerException` 4xx, `ValidationException`).
5. **NonFatalErrorReporter Callback Pattern**:
   - Vị trí: [`lib/core/utils/non_fatal_reporter.dart`](file:///d:/lt_dnt_khoi1/lib/core/utils/non_fatal_reporter.dart)
   - Báo cáo các lỗi bị "nuốt" (swallowed errors) hoặc lỗi thứ cấp (ghi cache lỗi khi remote thành công) cho pipeline giám sát mà không làm ngắt kết quả `Success` trả về cho người dùng.

### (b) Vì sao thiết kế như vậy?
- **Tại sao quy định: CHỈ báo reporter các lỗi bị nuốt (không trả ra trong `Failure`)?**
  - **Tránh ghi log trùng lặp (Prevent Duplicate Logging):**
    - Nếu Repository vừa ném lỗi ra ngoài qua `Failure(appEx)` vừa gọi `_nonFatalReporter(appEx)`, thì tầng UI/ErrorHandler khi nhận `Failure` sẽ ghi log lỗi đó lần thứ hai.
    - Quy tắc thiết kế chuẩn: Lỗi nào đã được trả về trong `Failure` thì để người gọi (Caller/Presentation) chịu trách nhiệm gửi vào pipeline `ErrorHandler`. Repository chỉ báo cáo những lỗi "chìm" (lỗi bị nuốt bên dưới, ví dụ: lỗi remote khi đã cứu vãn bằng cache, hoặc lỗi ghi cache khi remote đã thành công).
- **Tại sao lỗi 404 (NotFoundException) hay 4xx lại KHÔNG được rơi về Cache?**
  - Vì mã 404 nghĩa là tài nguyên đó **không tồn tại** trên hệ thống máy chủ. Nếu cố tình tìm trong Cache cục bộ và trả về một bản ghi cũ đã lưu từ trước, ứng dụng sẽ cung cấp thông tin sai lệch (Dữ liệu ma / Ghost data) cho người dùng.
- **Vai trò thực tế của khối `finally` ở đây là gì?**
  - Trong ngôn ngữ Dart, khối `finally` được bảo đảm thực thi bất kể khối `try` kết thúc bình thường (return) hay bị ngắt bởi `catch`. Ở đây, `finally` được dùng để dừng đồng hồ `Stopwatch` và ghi log thời gian xử lý I/O, phục vụ việc profiling hiệu năng và phát hiện các truy vấn chậm mà không cần duplicate code ở cả 2 nhánh thành công và thất bại.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Nếu mạng mất (`SocketException`) và Cache có dữ liệu, Repository sẽ trả về kết quả gì và ghi log ra sao?*
   - **Đáp án:** Repository nhận diện `SocketException` qua `AppException.from` thành `NetworkException`. Vì đây là lỗi mạng, hàm `_shouldFallbackToCache` cho phép đọc Cache. Cache có dữ liệu nên Repository trả về `Success(cachedData)` để giao diện người dùng vẫn xem được sổ chi tiêu offline. Đồng thời, Repository gọi `_nonFatalReporter` để ghi log cảnh báo rằng kết nối remote đã bị lỗi và đang hiển thị dữ liệu từ cache.
2. **Câu hỏi 2:** *Tại sao khi thêm mới giao dịch (`add`) mà Remote bị lỗi thì các em lại KHÔNG ghi vào Cache cục bộ?*
   - **Đáp án:** Để tránh tình trạng dữ liệu ảo chưa được máy chủ xác nhận (Ghost / Phantom Transactions) và tránh sự phức tạp của cơ chế 2-way sync conflict resolution. Theo hợp đồng đã chốt: GHI chỉ thành công khi Remote ghi nhận. Nếu Remote lỗi, trả ngay `Failure` để người dùng biết giao dịch chưa được tạo, bảo vệ tính nhất quán dữ liệu giữa client và server.
3. **Câu hỏi 3:** *Tại sao hàm `getSummary()` lại không gọi riêng một API remote khác mà lại tính toán trực tiếp từ `getAll()`?*
   - **Đáp án:** Vì toàn bộ các giao dịch đã được đồng bộ và quản lý bởi `getAll()`. Việc tái sử dụng `getAll()` giúp tận dụng ngay chiến lược offline cache sẵn có, giảm bớt số lượng request lên server, và hàm thuần `calculateSummary` tính toán trực tiếp từ mảng `List<Transaction>` giúp logic tính tổng thu/chi/số dư chạy tức thì trên RAM và cực kỳ dễ viết Unit Test độc lập.

---

## T-202: ErrorLogger & Structured Logging (R11)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Interface Pattern (Tính trừu tượng / Abstraction)**:
   - Vị trí: [`lib/core/error_handling/error_logger.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/error_logger.dart)
   - Khai báo `abstract interface class ErrorLogger` với các phương thức `log()`, `readAll()`, `clear()`. Tách biệt ranh giới giữa việc ghi log và phương tiện lưu trữ.
2. **Factory Constructor & Data Serialization (R2)**:
   - Vị trí: [`lib/core/error_handling/log_entry.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/log_entry.dart)
   - `LogEntry` chuẩn hóa cấu trúc dữ liệu lỗi (Structured Logging). `LogEntry.fromJson` (Factory constructor) phục hồi đối tượng từ JSON.
3. **Dependency Injection (Tiêm phụ thuộc)**:
   - Vị trí: [`lib/core/error_handling/file_logger.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/file_logger.dart)
   - Tiêm `directoryProvider` qua constructor của `FileLogger` giúp unit test hoàn toàn độc lập với platform channel native (`path_provider`).
4. **Đa hình (Polymorphism) & Chiến lược ghi log (Strategy-like pattern)**:
   - [`ConsoleLogger`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/console_logger.dart) và [`FileLogger`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/file_logger.dart) cùng hiện thực hóa `ErrorLogger`. Mỗi lớp có chiến lược xử lý dữ liệu phù hợp với môi trường của nó.
5. **Cơ chế Hàng đợi Tuần tự (Sequential Queue / Mutex via Future chaining)**:
   - Giải quyết bài toán concurrency khi ghi file mà không cần dùng package ngoài.

### (b) Vì sao thiết kế như vậy?
- **Tại sao `FileLogger` lại nuốt lỗi (catch không throw) khi ghi/đọc file thất bại?**
  - **Lý do phòng vệ cascade failure:** `ErrorLogger` là chốt chặn cuối cùng của hệ thống xử lý ngoại lệ. Nếu bản thân logger bị crash khi đang cố gắng ghi lại một lỗi khác (ví dụ: ổ đĩa đầy, mất quyền ghi file), việc ném ngoại lệ ra ngoài sẽ làm sập chính pipeline bắt lỗi, gây crash toàn bộ ứng dụng. Do đó, việc nuốt lỗi tại logger và chỉ ghi nhận ra console qua `dart:developer.log` là ngoại lệ hợp lệ duy nhất của quy tắc "không catch rỗng".
- **Tại sao cần giới hạn tối đa 500 bản ghi (`maxEntries = 500`)?**
  - Để bảo vệ dung lượng bộ nhớ thiết bị của người dùng (Log Rotation / Pruning). Một ứng dụng di động chạy lâu ngày có thể tích lũy hàng chục ngàn lỗi, việc duy trì tối đa 500 dòng JSON mới nhất vừa đủ để lập trình viên chẩn đoán sự cố vừa giữ kích thước file luôn dưới 200 KB.
- **Tại sao `ConsoleLogger.readAll()` lại trả về danh sách rỗng?**
  - Console chỉ là luồng xuất dữ liệu một chiều (`stdout`) do hệ điều hành và IDE quản lý. Dart không hỗ trợ đọc ngược lại bộ đệm màn hình console. Thiết kế trả về `[]` và `clear()` no-op giúp tuân thủ trọn vẹn hợp đồng `ErrorLogger` mà không sinh ra lỗi giả lập.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Nếu nhiều tiến trình hoặc nhiều sự kiện bất đồng bộ cùng ghi log một lúc thì `FileLogger` có bị lỗi ghi đè (race condition) hay lẫn dòng không?*
   - **Đáp án:** Không thể bị lẫn dòng. Nhóm đã cài đặt cơ chế khóa tuần tự `_synchronized` dựa trên việc nối chuỗi `Future` (`_lock = _lock.then(...)`). Mọi yêu cầu ghi/đọc/xóa đều được xếp hàng đợi và thực thi tuần tự lần lượt, đảm bảo dữ liệu ghi vào file JSON Lines luôn toàn vẹn.
2. **Câu hỏi 2:** *Tại sao các em lại dùng định dạng JSON Lines (mỗi dòng một JSON) thay vì lưu một mảng JSON `[...]` lớn?*
   - **Đáp án:** Định dạng JSON Lines cho phép append dòng mới cực nhanh mà không cần parse lại toàn bộ cây JSON lớn. Khi có một dòng bị lỗi/hỏng dữ liệu (ví dụ do app bị kill đột ngột khi đang ghi), `readAll()` chỉ cần bỏ qua dòng đó và tiếp tục đọc các dòng hợp lệ khác bình thường, không làm hỏng toàn bộ lịch sử log như định dạng mảng JSON thông thường.
3. **Câu hỏi 3:** *Tại sao trong `ConsoleLogger` lại dùng `dart:developer.log` mà không dùng lệnh `print()` quen thuộc?*
   - **Đáp án:** Vì lệnh `print()` không thể phân biệt được level, không kèm được stack trace hay mã lỗi có cấu trúc, và `print()` có thể làm tràn log khi build release. `dart:developer.log` hỗ trợ truyền `name`, `level`, `error`, `stackTrace` chuẩn hóa và tích hợp trực tiếp vào Dart DevTools để lọc log chuyên nghiệp.

---

## T-203: ErrorMessageMapper (User-Friendly Translation Pipeline) (R9, R11)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Exhaustive Pattern Matching trên Sealed Class (R9)**:
   - Vị trí: [`lib/core/error_handling/error_message_mapper.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/error_message_mapper.dart)
   - Sử dụng cú pháp `switch (e)` expression trên `sealed class AppException`. Trình biên dịch Dart 3.x ép buộc phải xử lý vét cạn 100% tất cả các trường hợp lớp con.
2. **Single Responsibility Principle (SRP) & Mapper Pattern**:
   - `ErrorMessageMapper` chỉ có duy nhất một trách nhiệm: ánh xạ đối tượng ngoại lệ kỹ thuật sang thông điệp tiếng Việt thân thiện.
   - Không chứa logic quyết định `canRetry` (được tách sang `ErrorHandler` ở T-204).
3. **Dependency Injection Readiness**:
   - Sử dụng `const constructor` và phương thức instance `messageFor(AppException e)` (thay vì static) để dễ dàng tiêm vào `ErrorHandler` và thay thế khi cần bản địa hóa (i18n) hoặc viết mock trong test.

### (b) Vì sao thiết kế như vậy?
- **Tại sao tách riêng `ErrorMessageMapper` mà không để luôn thông báo tiếng Việt trong từng `AppException`?**
  - **Tách biệt mối quan tâm và đa ngôn ngữ:** `AppException` thuộc về Core Logic, thông điệp trong exception là thông tin kỹ thuật bằng tiếng Anh kèm chi tiết mã lỗi để lập trình viên gỡ lỗi. Giao diện người dùng thì cần câu chữ tiếng Việt lịch sự, dễ hiểu, không để lộ chi tiết nội bộ (`SocketException`, `TypeError`). Tách riêng Mapper giúp sau này nếu ứng dụng muốn hỗ trợ song ngữ (Anh - Việt), ta chỉ cần thêm một Mapper mới mà không phải sửa đổi bất kỳ dòng code nào trong cây `AppException`.
- **Tại sao `ValidationException` lại trả về chính `e.message` của nó trong khi các lỗi khác lại được ghi đè câu thông báo?**
  - Vì `ValidationException` được sinh ra từ các quy tắc nghiệp vụ ở tầng Domain (`TransactionRules`). Thông điệp của nó đã được trau chuốt tỉ mỉ chỉ rõ ràng trường nào bị sai (ví dụ: "Tiêu đề không được để trống", "Số tiền phải lớn hơn 0"). Các lỗi khác như mạng, server, parse là lỗi kỹ thuật hệ thống nên cần một thông điệp thân thiện chung.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Điều gì đảm bảo khi sau này một thành viên khác thêm một loại exception mới (ví dụ `AuthException`) vào `AppException`, ứng dụng sẽ không quên hiển thị thông báo cho lỗi đó?*
   - **Đáp án:** Vì `AppException` là một `sealed class`. Biểu thức `switch (e)` trong `ErrorMessageMapper` sẽ lập tức bị trình biên dịch Dart 3 báo lỗi compile ngay tại thời điểm build nếu thiếu case cho `AuthException`. Lập trình viên bắt buộc phải bổ sung câu thông báo thì code mới build được.
2. **Câu hỏi 2:** *Tại sao `ServerException` lại phân nhánh thông báo theo `statusCode` (4xx và 5xx)?*
   - **Đáp án:** Vì bản chất của hai nhóm mã HTTP này hoàn toàn khác nhau đối với người dùng. Mã 5xx là lỗi sập server/quá tải nội bộ phía máy chủ nên cần thông báo người dùng "thử lại sau". Còn mã 4xx là do yêu cầu từ phía client gửi lên không hợp lệ, không thể tự khỏi nếu chỉ thử lại mà không thay đổi thao tác.
3. **Câu hỏi 3:** *Tại sao phương thức `messageFor` lại không viết `static` cho tiện gọi mà lại dùng instance method?*
   - **Đáp án:** Để tuân thủ nguyên lý Inversion of Control (IoC) và Dependency Injection. Khi `messageFor` là instance method và lớp có `const constructor`, ta có thể tiêm `ErrorMessageMapper` vào `ErrorHandler` qua constructor. Điều này cho phép trong Unit Test có thể mock hoặc hoán đổi mapper mà không làm ảnh hưởng đến các module khác.

---

## T-204: ErrorHandler & Centralized Error Handling Pipeline (R11)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Pipeline Pattern / Pipes and Filters (R11)**:
   - Vị trí: [`lib/core/error_handling/error_handler.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/error_handler.dart)
   - Thiết kế luồng xử lý ngoại lệ tập trung 5 bước tuần tự và độc lập:
     1. `_normalize`: Chuẩn hóa lỗi thô thành `AppException`.
     2. `_classify`: Phân loại `Severity`, nâng cấp lên tối thiểu `error` nếu `source == 'global'`.
     3. `_log`: Đóng gói `LogEntry` và gửi độc lập tới danh sách `ErrorLogger`.
     4. `_decideRetry`: Quyết định cờ `canRetry` dựa trên bản chất có thể tự phục hồi của ngoại lệ.
     5. `_toUserMessage`: Chuyển ngữ sang thông điệp tiếng Việt thân thiện qua `ErrorMessageMapper`.
2. **Dependency Injection (Inversion of Control - IoC)**:
   - `ErrorHandler` nhận `List<ErrorLogger>` và `ErrorMessageMapper` qua constructor, không tạo đối tượng phụ thuộc bên trong.
3. **Encapsulation & Information Hiding (Mô hình UserFacingError)**:
   - Vị trí: [`lib/core/error_handling/user_facing_error.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/user_facing_error.dart)
   - Đóng gói toàn bộ kết quả của pipeline thành một đối tượng bất biến (`const`) chỉ chứa 3 thông tin cần thiết cho UI: `message`, `canRetry`, `severity`, che giấu hoàn toàn stack trace và các chi tiết kỹ thuật nhạy cảm.
4. **Fault Isolation (Cô lập lỗi)**:
   - Trong bước `_log`, mỗi lời gọi logger được bọc `try-catch` riêng biệt. Một logger gặp lỗi không làm ảnh hưởng đến các logger khác và không làm sập pipeline.
5. **Defensive Programming (Phòng thủ ngoại lệ tầng chót)**:
   - Khối `try-catch` bao trùm toàn bộ phương thức `handle()` đảm bảo cam kết "không bao giờ ném ngoại lệ", luôn trả về fallback `UserFacingError(severity: critical)` nếu pipeline gặp sự cố bất ngờ.

### (b) Vì sao thiết kế như vậy?
- **Tại sao lại chia thành 5 bước tuần tự bằng các private method riêng biệt?**
  - **Single Responsibility Principle (SRP) và Khả năng bảo trì:** Mỗi bước chỉ thực hiện đúng một nhiệm vụ rõ ràng. Khi cần thay đổi thuật toán quyết định retry hay thêm quy tắc phân loại severity, lập trình viên chỉ cần sửa đúng hàm private tương ứng mà không làm ảnh hưởng đến các bước còn lại. Đồng thời, cấu trúc 5 bước ánh xạ 1:1 với sơ đồ luồng kiến trúc, giúp sinh viên cực kỳ tự tin khi trình bày trước hội đồng phản biện.
- **Tại sao `source == 'global'` lại nâng severity lên tối thiểu `error`?**
  - **Cơ chế Safety Net:** Khi một lỗi lọt qua tất cả các khối try-catch và ErrorBoundary cục bộ để rơi vào handler toàn cục (`FlutterError.onError` hay `PlatformDispatcher`), điều đó chứng tỏ hệ thống phòng vệ tại chỗ đã bị thủng. Kể cả lỗi đó vốn chỉ là `info` hay `warning`, nó vẫn cần được cảnh báo ở mức độ `error` để đội ngũ phát triển nhận biết và bổ sung ranh giới bắt lỗi tại màn hình đó.
- **Tại sao nhóm lỗi `ValidationException`, `NotFoundException`, `ServerException 4xx` lại có `canRetry = false`?**
  - Vì đây là các lỗi mang tính tất định (deterministic):
    - `ValidationException` là do người dùng nhập sai (ví dụ số tiền âm), nếu bấm "Thử lại" mà không sửa số tiền thì 100% vẫn sẽ tiếp tục thất bại.
    - `NotFoundException` và `4xx` là lỗi tài nguyên không tồn tại hoặc sai yêu cầu client, không thể tự khỏi khi gửi lại cùng một request.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Nếu một trong các `ErrorLogger` bị sập (ví dụ `FileLogger` lỗi ghi đĩa đầy) thì quy trình xử lý lỗi có bị dừng lại không?*
   - **Đáp án:** Tuyệt đối không. Tại bước `_log`, nhóm áp dụng nguyên lý **Cô lập lỗi (Fault Isolation)**: vòng lặp duyệt qua các logger được bọc `try-catch` độc lập cho từng logger. Nếu `FileLogger` ném lỗi, lỗi đó được ghi nhận qua `developer.log` và pipeline vẫn tiếp tục gửi `LogEntry` đến các logger còn lại (như `ConsoleLogger`), sau đó hoàn tất các bước tiếp theo bình thường.
2. **Câu hỏi 2:** *Tại sao trong `_decideRetry` lỗi `UnknownException` lại được đặt `canRetry = true`?*
   - **Đáp án:** Vì `UnknownException` đại diện cho các lỗi bất ngờ runtime (như race condition bất đồng bộ hoặc trạng thái tạm thời chưa xác định). Việc cho phép người dùng bấm "Thử lại" cung cấp một cơ hội để ứng dụng khởi động lại thao tác hoặc nạp lại trạng thái mới mà không bắt người dùng phải tắt app mở lại.
3. **Câu hỏi 3:** *Lớp `UserFacingError` có vai trò kiến trúc gì trong Clean Architecture?*
   - **Đáp án:** `UserFacingError` đóng vai trò là ranh giới trừu tượng hóa lỗi (Error Abstraction Barrier) giữa Core/Data/Domain với tầng Presentation. Tầng Presentation không cần biết `SocketException` hay `HttpStatusError 500` là gì, nó chỉ nhận `UserFacingError` để biết: hiển thị câu gì cho người dùng (`message`), có hiện nút thử lại không (`canRetry`) và nên vẽ màu gì / widget nào (`severity`).

---

## T-205: Global Error Hooks (3-Tier Safety Net & Zone Protection) (R10, R11)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Facade Pattern / Utility Class (`GlobalErrorHooks`)**:
   - Vị trí: [`lib/core/error_handling/global_error_hooks.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/global_error_hooks.dart)
   - Đóng gói toàn bộ việc đăng ký các hook bắt lỗi phức tạp của Flutter Engine và Dart Runtime vào 2 phương thức tĩnh trực quan: `install(handler)` và `runGuarded(body, handler)`.
2. **Adapter & Callback Pattern**:
   - Chuyển đổi các chữ ký callback đa dạng của Flutter (`FlutterExceptionHandler` nhận `FlutterErrorDetails`, `bool Function(Object, StackTrace)` của `PlatformDispatcher`, và error callback của `runZonedGuarded`) về một giao diện xử lý thống nhất: `handler.handle(error, stack, source: 'global')`.
3. **Safety Net Elevation Pattern**:
   - Khi bất kỳ lỗi nào được đẩy qua từ các global hooks này, tham số `source: 'global'` báo hiệu cho `ErrorHandler` tự động nâng mức độ nghiêm trọng lên tối thiểu `Severity.error`.
4. **Clean Architecture Entrypoint (Zone-safe Initialization)**:
   - Vị trí: [`lib/main.dart`](file:///d:/lt_dnt_khoi1/lib/main.dart)
   - Khởi tạo ứng dụng bên trong cùng một Zone với `WidgetsFlutterBinding.ensureInitialized()`, loại bỏ triệt để hiện tượng Zone Mismatch.

### (b) Vì sao thiết kế như vậy?
- **Tại sao cần tới 3 lớp lưới an toàn mà không chỉ dùng một cái?**
  - **Mỗi lớp có một phạm vi bắt lỗi (Error Scope) hoàn toàn khác nhau trong Flutter:**
    1. `FlutterError.onError`: CHỈ bắt các lỗi phát sinh trong cây Widget, build, layout và render pipeline của framework. Nó không thể bắt được lỗi xảy ra trong các hàm `async` hay microtask không await.
    2. `PlatformDispatcher.instance.onError`: Bắt các lỗi bất đồng bộ lọt ra ngoài framework ở cấp Engine/Isolate, nhưng nó không có ngữ cảnh Zone riêng biệt và trong một số môi trường cô lập có thể bị hạn chế.
    3. `runZonedGuarded`: Thiết lập một Zone biệt lập cho toàn bộ tiến trình Dart, đảm bảo mọi lỗi async unhandled trong zone đó đều bị chặn đứng, đồng thời đồng bộ Zone cho Flutter Binding.
  - Việc kết hợp cả 3 lớp tạo thành một hệ thống phòng thủ đa tầng (Defense in Depth), đảm bảo 0% lỗi có thể lọt ra ngoài làm sập ứng dụng.
- **Tại sao `PlatformDispatcher.instance.onError` bắt buộc phải `return true`?**
  - Trong Flutter Engine, nếu callback này trả về `false` hoặc `null`, engine sẽ hiểu rằng lỗi đó chưa được ứng dụng xử lý (unhandled error). Khi đó, engine sẽ báo cáo lỗi lên tầng OS host (Android/iOS) và hệ điều hành sẽ cưỡng chế đóng (force kill) tiến trình ứng dụng. Việc `return true` là cam kết: "Ứng dụng đã hấp thụ và ghi nhận lỗi an toàn, hãy tiếp tục duy trì tiến trình".
- **Tại sao `WidgetsFlutterBinding.ensureInitialized()` và `runApp()` phải nằm trong CÙNG MỘT Zone?**
  - **Tránh lỗi "Zone mismatch":** `WidgetsFlutterBinding` khởi tạo và gán các handler giao tiếp nhị phân (BinaryMessenger), xử lý cử chỉ (GestureBinding) và vòng lặp sự kiện vào Zone hiện tại. Nếu gọi `ensureInitialized()` ở Root Zone nhưng lại bọc `runApp()` trong Zone con của `runZonedGuarded`, các callback sự kiện và Future/Timer sẽ bị phân tán giữa hai Zone khác nhau, gây ra hiện tượng deadlock, mất sự kiện hoặc lỗi async không thể bắt được.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Nếu đã có `PlatformDispatcher.instance.onError` trong Flutter mới, tại sao các em vẫn cần dùng `runZonedGuarded`?*
   - **Đáp án:** Vì `runZonedGuarded` tạo ra một ranh giới Zone đóng gói toàn bộ vòng đời ứng dụng ngay từ hàm `main()`. Nó đảm bảo rằng việc khởi tạo binding và chạy app nằm trong cùng một Zone (tránh Zone mismatch), đồng thời hỗ trợ bắt các lỗi async unhandled trong các gói thư viện hoặc code Dart thuần mà không hoàn toàn phụ thuộc vào việc Flutter Engine dispatch sự kiện.
2. **Câu hỏi 2:** *Trong debug mode, nếu `FlutterError.onError` bắt lỗi thì lập trình viên có bị mất "màn hình đỏ" và console log quen thuộc không?*
   - **Đáp án:** Dạ không. Nhóm đã kiểm tra điều kiện `if (kDebugMode) FlutterError.presentError(details);`. Lệnh này đảm bảo trong lúc phát triển, màn hình đỏ và log chi tiết của Flutter framework vẫn hiển thị đầy đủ trên console và IDE, đồng thời lỗi vẫn được pipeline của nhóm ghi nhận vào `FileLogger` và `ErrorHandler` một cách hoàn hảo.
3. **Câu hỏi 3:** *Làm thế nào để kiểm thử các global hook này trong Unit Test mà không làm hỏng trình chạy test `flutter test`?*
   - **Đáp án:** Trong `test/core/error_handling/global_error_hooks_test.dart`, tại phương thức `setUp`, nhóm đã lưu lại tham chiếu gốc `originalFlutterOnError` và `originalPlatformDispatcherOnError`. Sau khi test xong, khối `tearDown` luôn khôi phục lại các handler ban đầu của Flutter Test Framework, đảm bảo tính cô lập và không gây hiệu ứng phụ (side effects) cho các test case khác.

---

## T-206: Composition Root & Dependency Injection (R5, R6)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Composition Root Pattern (R5, R6)**:
   - Vị trí: [`lib/core/di/app_dependencies.dart`](file:///d:/lt_dnt_khoi1/lib/core/di/app_dependencies.dart)
   - Tập trung toàn bộ logic khởi tạo, cấu hình và nối dây (wiring) của toàn bộ hệ thống vào một điểm duy nhất tại thời điểm khởi động ứng dụng (`main()`).
2. **Pure Constructor Injection (Dependency Injection thuần Dart)**:
   - Hoàn toàn không phụ thuộc các framework DI bên ngoài (`get_it`, `injectable`). Giữ cho tầng Domain và Data thuần khiết, trong sáng và độc lập.
3. **Open-Closed Principle (OCP) & Inversion of Control (IoC)**:
   - Các tham số `overrides` trong `buildDependencies` cho phép hoán đổi bất kỳ DataSource, Logger hay Usecase nào mà KHÔNG cần sửa đổi một dòng code nào trong Domain hay UI.
4. **State Management Integration via MultiProvider**:
   - Vị trí: [`lib/app.dart`](file:///d:/lt_dnt_khoi1/lib/app.dart)
   - Cung cấp `AppDependencies` xuống toàn bộ cây widget qua `MultiProvider`, bao gồm `Provider<ErrorLogger>` cho `fileLogger` (phục vụ màn hình Log Viewer T-306).

### (b) Vì sao thiết kế như vậy?
- **Tại sao lại dùng hàm `buildDependencies` thuần túy thay vì dùng `get_it`?**
  - **Tránh Service Locator Anti-pattern:** `get_it` biến các dependency thành các singleton toàn cục bị ẩn giấu (hidden dependencies), khiến code khó test, khó phát hiện phụ thuộc vòng, và vi phạm nguyên lý Inversion of Control. Ngược lại, Pure Constructor Injection ép mọi phụ thuộc phải hiện diện tường minh trong constructor, giúp dễ kiểm thử, minh bạch và giải thích dễ dàng cho hội đồng phản biện.
- **Tại sao `AppDependencies` lại lưu riêng tham chiếu `fileLogger` và đăng ký `Provider<ErrorLogger>`?**
  - Để chuẩn bị cho tính năng **Log Viewer (T-306)** ở Sprint 3: Màn hình này cần đọc và hiển thị lịch sử các lỗi đã lưu bền vững trên đĩa. Thay vì phải phụ thuộc vào lớp cụ thể `FileLogger`, UI chỉ cần lấy `context.read<ErrorLogger>()` để gọi `readAll()`, tuân thủ nguyên tắc Dependency Inversion.
- **Tại sao `FailureSimulator` được đặt ở `lib/core/simulation/`?**
  - Vì nó đóng vai trò là trạng thái điều khiển lỗi dùng chung (Shared Simulation State). Cả tầng Data (`FakeRemoteDataSource`) và tầng Presentation (Settings/Debug Panel) đều cần truy xuất nó. Đặt ở `core/` giúp tầng Presentation có thể thay đổi chế độ lỗi mà không vi phạm ranh giới kiến trúc (tuyệt đối không import tầng Data).

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Composition Root là gì và tại sao lại đặt việc lắp ráp ở đây mà không khởi tạo trực tiếp trong từng class?*
   - **Đáp án:** Composition Root là nơi duy nhất trong ứng dụng chịu trách nhiệm tạo và kết nối các đối tượng phụ thuộc với nhau. Nếu từng class tự tạo dependency bên trong (`new FakeRemoteDataSource()`), chúng sẽ bị gắn chặt (tightly coupled), không thể viết Unit Test và không thể thay thế linh hoạt. Composition Root giúp toàn bộ hệ thống tuân thủ nguyên lý Dependency Inversion.
2. **Câu hỏi 2:** *Nếu sau này dự án muốn chuyển từ `FakeRemoteDataSource` sang gọi REST API thật bằng `HttpClient` thì cần sửa những file nào?*
   - **Đáp án:** Nhóm chỉ cần tạo lớp `HttpRemoteDataSource implements DataSource<TransactionModel>` và thay đổi đúng 1 dòng khởi tạo tại `buildDependencies()` trong `app_dependencies.dart`. Toàn bộ 6 usecases của tầng Domain, Repository và toàn bộ giao diện tầng Presentation đều giữ nguyên 100% không cần sửa một dòng nào.
3. **Câu hỏi 3:** *Tại sao các usecase lại được đăng ký riêng lẻ trong `MultiProvider` ở `app.dart`?*
   - **Đáp án:** Để tuân thủ Interface Segregation Principle (ISP). Một màn hình hoặc ViewModel chỉ cần lắng nghe usecase mà nó thực sự sử dụng (ví dụ: màn hình Danh sách chỉ cần `GetTransactions`, màn hình Thêm chỉ cần `AddTransaction`) thay vì phải nhận toàn bộ cả kho `AppDependencies`.


---

## T-304: ErrorBoundary & ErrorWidget.builder (R10)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Two-Tier UI Safety Net Pattern (Kiến trúc phòng thủ 2 lớp cho giao diện người dùng) (R10)**:
   - **Lớp 1 (Framework / Build Render Error):** [`lib/core/error_handling/error_widget_setup.dart`](file:///d:/lt_dnt_khoi1/lib/core/error_handling/error_widget_setup.dart) cấu hình `installErrorWidgetBuilder()` thiết lập `ErrorWidget.builder`. Khi một widget con gặp lỗi cú pháp hoặc ngoại lệ runtime trong hàm `build()`, Flutter sẽ thay thế nó bằng `ErrorView.compact` (thông điệp an toàn, không có nút Thử lại, không crash app thành Red Screen of Death).
   - **Lớp 2 (Screen / Component State Boundary):** [`lib/presentation/widgets/error_boundary.dart`](file:///d:/lt_dnt_khoi1/lib/presentation/widgets/error_boundary.dart) lắng nghe `errorSource` (`ValueListenable<UserFacingError?>`) từ Notifier. Khi phát sinh lỗi nghiêm trọng cấp màn hình (ví dụ: bug tầng dưới trong khối `_run`), `ErrorBoundary` hiển thị `ErrorView` toàn phần thay cho `child`, cho phép người dùng bấm "Thử lại" (`onRetry`) hoặc "Bỏ qua" (`onDismiss`).
2. **Decorator / Wrapper Pattern**:
   - `ErrorBoundary` bao bọc lấy `child` mà không làm thay đổi logic bên trong của `child`. Tận dụng `ValueListenableBuilder.child` để tránh việc build lại `child` không cần thiết khi trạng thái lỗi cập nhật.
3. **Information Hiding & Defensive UI**:
   - Giao diện người dùng tuyệt đối không tiếp xúc với stack trace kỹ thuật hay exception thô. Mọi lỗi đều chuyển thành `UserFacingError` chứa thông điệp thân thiện bằng tiếng Việt và cờ `canRetry`.
4. **Phân định ranh giới trách nhiệm (Separation of Concerns & Action Error Isolation)**:
   - Các lỗi thao tác thông thường trên biểu mẫu (nhập sai validation, lỗi mạng khi submit) được giữ ở cấp độ `SnackBar` (`actionError`) hoặc `fieldErrors`, **tuyệt đối không kích hoạt `ErrorBoundary`**. Điều này giúp bảo vệ tối đa dữ liệu người dùng đang nhập dở trên Form, tránh việc form bị biến mất gây ức chế cho người dùng.

### (b) Vì sao thiết kế như vậy?
- **Tại sao Flutter không có cơ chế `try-catch` bọc widget con giống React `componentDidCatch`?**
  - Trong Flutter, việc dựng cây widget (`Widget`), cây phần tử (`Element`) và cây hiển thị (`RenderObject`) diễn ra theo một pipeline được điều phối chặt chẽ bởi Flutter Framework Engine. Phương thức `build()` của một widget con không được gọi trực tiếp bên trong phương thức `build()` của widget cha mà được Framework gọi tách biệt thông qua `ComponentElement.performRebuild()`. Khối `try-catch` trong Dart chỉ bắt được ngoại lệ đồng bộ trong cùng một call frame (ngăn xếp lời gọi hàm). Vì vậy, viết `try { return child; } catch (e) { ... }` trong hàm `build` của một widget cha là hoàn toàn vô tác dụng đối với các lỗi phát sinh bên trong widget con. Cơ chế chính thống duy nhất để can thiệp lỗi render của widget con là thông qua hook `ErrorWidget.builder` của Flutter Framework kết hợp với State Error Boundary (`ValueListenable<UserFacingError?>`).
- **Tại sao `installErrorWidgetBuilder` TUYỆT ĐỐI KHÔNG ĐƯỢC GHI LOG?**
  - **Tránh ghi log trùng lặp (Duplicate Logging):** Trước khi Flutter Framework gọi `ErrorWidget.builder` để vẽ giao diện thay thế, nó luôn luôn chuyển tiếp lỗi đó vào `FlutterError.onError`. Ở ticket T-205, hệ thống đã cài đặt `GlobalErrorHooks.install` để bắt mọi sự kiện từ `FlutterError.onError` và chuyển tới `ErrorHandler` để ghi vào `FileLogger`. Nếu trong `ErrorWidget.builder` ta lại tiếp tục gọi ghi log, thì mỗi lỗi render sẽ bị ghi thành 2 bản ghi trùng lặp trong file nhật ký.
- **Tại sao lỗi khi submit Form lại hiển thị qua `SnackBar` mà KHÔNG kích hoạt `ErrorBoundary`?**
  - Để bảo vệ dữ liệu người dùng (User Input Preservation). Giả sử người dùng vừa dành 5 phút điền một biểu mẫu giao dịch chi tiết, khi bấm Lưu thì gặp sự cố mạng hoặc server 500. Nếu kích hoạt `ErrorBoundary` thay thế toàn bộ Form bằng `ErrorView`, người dùng sẽ bị mất toàn bộ dữ liệu đang nhập dở. Bằng cách tách biệt `actionError` hiển thị qua `SnackBar` nổi có nút "Thử lại", Form vẫn được giữ nguyên trên màn hình cùng các giá trị đã nhập, mang lại trải nghiệm người dùng tốt nhất.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Tại sao các em không viết một widget có khối `try-catch` bọc `child` trong hàm `build()` mà phải dùng `ValueListenableBuilder` cho `ErrorBoundary`?*
   - **Đáp án:** Vì Flutter không hỗ trợ bắt lỗi của widget con bằng `try-catch` đồng bộ. Hàm `build()` của widget con được framework gọi bên trong `Element.performRebuild()` trên luồng render của framework chứ không nằm trong call-stack của widget cha. Do đó, lỗi render cấp framework bắt buộc phải do `ErrorWidget.builder` xử lý; còn `ErrorBoundary` của nhóm là ranh giới cấp trạng thái (State-level Boundary), nhận tín hiệu `boundaryError` từ ViewModel thông qua `ValueListenable` để hoán đổi giao diện an toàn khi có lỗi nghiêm trọng ở tầng logic.
2. **Câu hỏi 2:** *Tại sao trong hàm `installErrorWidgetBuilder()` các em lại không gọi `ErrorHandler.handle()` hay ghi log vào `FileLogger`?*
   - **Đáp án:** Để tránh lỗi duplicate log (ghi log 2 lần). Trước khi gọi `ErrorWidget.builder`, Flutter Framework luôn tự động đẩy ngoại lệ render vào `FlutterError.onError`. Hệ sinh thái lỗi của nhóm đã có `GlobalErrorHooks` bắt toàn bộ `FlutterError.onError` và ghi log tập trung. Do đó, `ErrorWidget.builder` chỉ có duy nhất một trách nhiệm là vẽ UI fallback an toàn cho người dùng, tuân thủ nguyên lý Trách nhiệm đơn lẻ (SRP).
3. **Câu hỏi 3:** *Nếu người dùng nhập sai tiêu đề hoặc mạng bị rớt khi bấm nút "Lưu" trên Form thì `ErrorBoundary` có được kích hoạt không, và tại sao?*
   - **Đáp án:** Dạ không. Nhóm đã phân tách ranh giới rõ ràng: Lỗi thẩm định nhập liệu sẽ đổ vào `fieldErrors` hiển thị ngay dưới ô nhập liệu; còn lỗi mạng tạm thời khi bấm Lưu sẽ đổ vào `actionError` để hiển thị `SnackBar` nổi kèm nút "Thử lại". Toàn bộ Form và dữ liệu người dùng đã gõ được giữ nguyên vẹn 100%, không bị `ErrorBoundary` che khuất, giúp người dùng không phải nhập lại từ đầu.


---

## T-305: Error Simulator Screen (R10, R11)

### (a) Khái niệm OOP và Design Patterns đã dùng
1. **Simulation Control Pattern / Shared State Pattern**:
   - Vị trí: [`lib/presentation/screens/error_simulator_screen.dart`](file:///d:/lt_dnt_khoi1/lib/presentation/screens/error_simulator_screen.dart) và [`lib/core/simulation/failure_mode.dart`](file:///d:/lt_dnt_khoi1/lib/core/simulation/failure_mode.dart).
   - `FailureSimulator` (kế thừa `ChangeNotifier`) quản lý chế độ lỗi dùng chung giữa tầng Data (`FakeRemoteDataSource`) và Presentation (`ErrorSimulatorScreen`). Cho phép thay đổi tức thì chế độ lỗi mạng, timeout, server 500 hoặc JSON hỏng mà không vi phạm ranh giới kiến trúc Clean Architecture (UI tuyệt đối không import tầng Data).
2. **Decomposition & Clean Code Component Pattern (T-402)**:
   - Toàn bộ 5 khối chức năng được tách biệt thành các widget con chuyên biệt trong [`lib/presentation/widgets/simulator_action_cards.dart`](file:///d:/lt_dnt_khoi1/lib/presentation/widgets/simulator_action_cards.dart) (`ModeSelectorCard`, `ReloadListCard`, `BuildErrorCard`, `AsyncErrorCard`, `ValidationErrorCard`).
   - Mọi hàm `build()` đều dưới 40 dòng, đảm bảo tính đóng gói và dễ bảo trì.
3. **Listenable Composition Pattern**:
   - Sử dụng `ListenableBuilder` với `Listenable.merge([simulator, notifier])` để tự động tái tạo giao diện khi một trong hai đối tượng phát tín hiệu thay đổi trạng thái.

### (b) Vì sao thiết kế như vậy?
- **Tại sao `FailureSimulator` được đặt ở `lib/core/simulation/` thay vì ở `lib/data/`?**
  - Để tuân thủ Dependency Inversion và Clean Architecture. Cả tầng Data (`FakeRemoteDataSource`) và tầng Presentation (`ErrorSimulatorScreen`) đều cần truy xuất trình giả lập lỗi. Đặt tại `core/` giúp tầng Presentation có thể thay đổi chế độ lỗi mà không phải import bất cứ file nào từ tầng Data (`lib/data/`).
- **Nút "Gây lỗi trong build" minh họa cho cơ chế nào?**
  - Minh họa cho `ErrorWidget.builder` (đã cài đặt ở T-304 qua `installErrorWidgetBuilder`). Khi widget con cố tình ném lỗi trong phương thức `build()`, Flutter Framework sẽ thay thế widget con bị lỗi bằng `ErrorView.compact` với thông điệp *"Màn hình gặp sự cố khi hiển thị. Hãy quay lại và thử lại."*, ngăn chặn hoàn toàn hiện tượng sập app ra màn hình đỏ (Red Screen of Death).
- **Nút "Gây lỗi async ngoài widget tree" minh họa cho cơ chế nào?**
  - Minh họa cho hệ sinh thái lưới an toàn toàn cục 3 lớp (3-tier Global Safety Net: `PlatformDispatcher.onError` và `runZonedGuarded`). Khi một lỗi bất đồng bộ phát sinh bên ngoài widget tree, nó được bắt tập trung, chuyển vào `ErrorHandler` và tự động ghi log vào `FileLogger`, người dùng có thể mở ngay `LogViewerScreen` từ AppBar để kiểm tra bản ghi nhật ký.

### (c) 3 Câu hỏi phản biện giảng viên có thể hỏi & Đáp án ngắn
1. **Câu hỏi 1:** *Màn hình Error Simulator này phục vụ mục đích gì trong đồ án?*
   - **Đáp án:** Phục vụ việc kiểm chứng và minh họa trực quan (Live Demonstration) toàn bộ các kịch bản lỗi của hệ thống trước hội đồng giảng viên: từ lỗi mất mạng, quá thời gian chờ, lỗi server 500, lỗi parse JSON, lỗi render trong build, lỗi async ngoài widget tree đến lỗi validation của Domain mà không cần can thiệp hệ thống hay giả lập rớt mạng vật lý.
2. **Câu hỏi 2:** *Tại sao tầng UI của màn hình này có thể điều khiển được lỗi của FakeRemoteDataSource mà không hề import tầng Data?*
   - **Đáp án:** Nhóm áp dụng nguyên lý Dependency Inversion. Cả hai tầng đều phụ thuộc vào lớp trừu tượng dùng chung `FailureSimulator` nằm tại `lib/core/simulation/`. Tầng Presentation chỉ cập nhật `FailureSimulator.mode`, còn `FakeRemoteDataSource` đọc giá trị đó để quyết định ném ngoại lệ tương ứng. Hai tầng hoàn toàn độc lập với nhau.
3. **Câu hỏi 3:** *Khi bấm "Gây lỗi validation" với số tiền âm, lỗi này được phát hiện ở đâu và xử lý như thế nào?*
   - **Đáp án:** Giao dịch nháp (`TransactionDraft`) được gửi trực tiếp xuống Use Case `AddTransaction`. Use Case gọi `TransactionRules.validate` của tầng Domain để kiểm tra. Domain phát hiện số tiền âm và trả về `ValidationException(field: 'amount')`. `TransactionNotifier` bắt lỗi này đưa qua `ErrorHandler` để ghi log, sau đó đổ thông báo lỗi vào `fieldErrors['amount']` để hiển thị trực quan ngay tại thẻ demo mà không làm sập giao diện.
