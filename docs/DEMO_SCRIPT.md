# KỊCH BẢN THUYẾT MINH & THỰC NGHIỆM DEMO 5 PHÚT (DEMO_SCRIPT.md)

> **Dự án:** Sổ Chi Tiêu Cá Nhân (Expense Tracker)  
> **Thời lượng demo:** 5 phút (Khung chuẩn buổi bảo vệ đồ án)  
> **Mục tiêu:** Trình diễn trực quan luồng nghiệp vụ chuẩn, năng lực tự phục hồi khi gặp lỗi hạ tầng mạng, hệ thống phòng thủ đa tầng (Error Boundary & Global Hooks), và cơ chế ghi log tập trung.  

---

## ⏱️ BẢNG PHÂN BỔ THỜI GIAN VÀ TIẾN TRÌNH 5 PHÚT

| Mốc thời gian | Phân đoạn thực nghiệm | Mục tiêu kiểm chứng | Người thực hiện |
| :---: | :--- | :--- | :---: |
| **0:00 – 1:00** | **Phần 1: Luồng nghiệp vụ chuẩn (Happy Path)** | Xem danh sách 7 giao dịch mẫu, thống kê số dư, thêm giao dịch mới. | **SV B (Phạm Nhung)** |
| **1:00 – 3:00** | **Phần 2: Error Simulator & Khả năng chịu lỗi** | Mô phỏng 4 lỗi mạng/I/O (Network, Timeout, 500, Parse) & Lỗi build UI. | **SV A (Nguyễn Đức Hải)** |
| **3:00 – 4:00** | **Phần 3: Log Viewer & Structured Logging** | Lỗi unhandled async, xem nhật ký `app_errors.log`, lọc và mở StackTrace. | **SV A (Nguyễn Đức Hải)** |
| **4:00 – 5:00** | **Phần 4: Code Walkthrough then chốt** | Mở 3 file kiến trúc cốt lõi (`ErrorHandler`, `RepositoryImpl`, `ExceptionFactory`). | **SV B & SV A** |

---

## 📋 CHECKLIST CHUẨN BỊ TRƯỚC GIỜ BẢO VỆ (5 PHÚT TRƯỚC KHI LÊN BÀN)

- [ ] **1. Môi trường chạy:** Đã khởi động sẵn ứng dụng trên Android Emulator hoặc Windows Desktop (`flutter run -d windows` để khởi động tức thì, độ ổn định cao nhất).
- [ ] **2. Dữ liệu ban đầu:** Đảm bảo danh sách giao dịch hiển thị đúng **7 giao dịch mẫu** ban đầu (Số dư: `12.120.000 ₫`, Tổng thu: `17.000.000 ₫`, Tổng chi: `4.880.000 ₫`).
- [ ] **3. Chế độ lỗi:** Mở màn hình Simulator kiểm tra chế độ lỗi đang chọn là **`Bình thường (None)`**.
- [ ] **4. Làm sạch log:** Mở màn hình Log Viewer, nhấn biểu tượng thùng rác trên AppBar để làm sạch file log cũ.
- [ ] **5. Chuẩn bị IDE:** Mở sẵn 3 tab mã nguồn then chốt trên VS Code / Android Studio:
  - `lib/core/error_handling/error_handler.dart`
  - `lib/data/repositories/transaction_repository_impl.dart`
  - `lib/core/errors/exception_factory.dart`
- [ ] **6. Cấu hình thiết bị:** Bật chế độ "Không làm phiền" (Do Not Disturb), độ sáng màn hình 80-100%, pin thiết bị > 50% hoặc đang cắm sạc.

---

## 🔄 QUY TRÌNH RESET NHANH VỀ TRẠNG THÁI GỐC (< 15 GIÂY)

Khi cần xóa dữ liệu thử nghiệm để demo lại từ đầu cho Giảng viên:
1. **Bước 1:** Trên AppBar màn hình chính, nhấn icon con bọ (`Icons.bug_report_outlined`) -> Chọn lại chip **`Bình thường (None)`**.
2. **Bước 2:** Nhấn icon quyển sổ (`Icons.history_edu_outlined`) vào Log Viewer -> Nhấn icon thùng rác trên AppBar -> Chọn **Xóa toàn bộ**.
3. **Bước 3:** Nhấn phím `R` (Hot Restart) trên cửa sổ Terminal đang chạy `flutter run` (Dữ liệu In-Memory của `FakeRemoteDataSource` sẽ tự động khôi phục về nguyên bản 7 giao dịch mẫu).

---

## 🎬 KỊCH BẢN THỰC THI CHI TIẾT TỪNG PHÚT

### PHÚT 0:00 – 1:00: LUỒNG NGHIỆP VỤ BÌNH THƯỜNG (HAPPY PATH)
- **Người trình bày:** Sinh viên B (Phạm Nhung)
- **Mục tiêu:** Chứng minh các chức năng CRUD, tính toán tài chính và Domain Validation hoạt động hoàn hảo khi không có lỗi.

#### Các bước thao tác:
1. Mở màn hình chính `TransactionListScreen`. Chỉ vào thẻ thống kê số dư:
   - Tổng thu: `+17.000.000 ₫` | Tổng chi: `-4.880.000 ₫` | Số dư: `12.120.000 ₫`.
2. Cuộn nhẹ danh sách để thấy 7 giao dịch mẫu với đầy đủ icon danh mục và màu sắc.
3. Nhấn nút FloatingActionButton (`+`) góc dưới để mở `TransactionFormScreen`.
4. Nhập dữ liệu mới:
   - Chọn loại: **Chi tiêu (-)**.
   - Tiêu đề: `Ăn trưa tiếp đối tác`.
   - Số tiền: `120000` (120.000 ₫).
   - Danh mục: **Ăn uống** (`food`).
   - Nhấn **Lưu giao dịch**.

#### Kết quả mong đợi trên màn hình:
- Nút bấm hiện vòng xoay CircularProgressIndicator nhỏ trong ~300ms rồi tự đóng form.
- Quay về màn hình chính: Danh sách xuất hiện ngay giao dịch mới ở đầu; thẻ số dư cập nhật tức thì thành `12.000.000 ₫` (Tổng chi tăng lên `5.000.000 ₫`).
- Dưới màn hình hiện SnackBar xanh thông báo: *"Thêm giao dịch mới thành công!"*.

#### File code liên quan:
- `lib/presentation/screens/transaction_list_screen.dart`
- `lib/presentation/screens/transaction_form_screen.dart`
- `lib/domain/usecases/add_transaction.dart`

#### Câu nói gợi ý của người thuyết minh:
> *"Em xin phép mở đầu bằng luồng hoạt động bình thường của ứng dụng. Màn hình chính hiện 7 giao dịch mẫu cùng thẻ thống kê tài chính trực quan. Giờ em thêm nhanh một khoản chi tiêu 120.000đ cho Ăn uống. Khi bấm Lưu, dữ liệu được Domain thẩm định và Notifier cập nhật số dư tức thời về 12.000.000đ."*

---

### PHÚT 1:00 – 3:00: ERROR SIMULATOR & KHẢ NĂNG CHỊU LỖI (FAULT TOLERANCE)
- **Người trình bày:** Sinh viên A (Nguyễn Đức Hải)
- **Mục tiêu:** Chứng minh ứng dụng không bao giờ bị crash; tự động fallback cache offline khi mất mạng; Error Boundary bảo vệ giao diện.

#### Các bước thao tác:
1. Nhấn biểu tượng con bọ (`Icons.bug_report_outlined`) trên thanh AppBar để vào `ErrorSimulatorScreen`.
2. **Kịch bản 1 (Mất mạng - SocketException):**
   - Chọn chip **Mất mạng (Socket)**.
   - Nhấn nút **Tải lại danh sách (load)**.
   - *Kết quả:* Ứng dụng KHÔNG văng. Status box báo lỗi có thể thử lại. SnackBar cảnh báo xuất hiện: *"Không thể kết nối máy chủ. Đang hiển thị dữ liệu lưu tạm gần nhất."* kèm nút **Thử lại**. Dữ liệu danh sách vẫn hiển thị trọn vẹn nhờ fallback cache.
3. **Kịch bản 2 (Quá hạn kết nối - TimeoutException):**
   - Chọn chip **Quá hạn (Timeout)**.
   - Nhấn nút **Tải lại danh sách (load)**.
   - *Kết quả:* Sau độ trễ, SnackBar hiện câu thông báo thân thiện: *"Kết nối máy chủ quá hạn. Vui lòng thử lại sau."* với `canRetry: true`.
4. **Kịch bản 3 (Lỗi máy chủ - Server 500):**
   - Chọn chip **Lỗi máy chủ (500)** -> Nhấn **Tải lại danh sách (load)**.
   - *Kết quả:* Nhận diện mã 500, SnackBar báo: *"Máy chủ đang gặp sự cố nội bộ. Vui lòng thử lại sau."*.
5. **Kịch bản 4 (JSON Parse Error):**
   - Chọn chip **JSON hỏng (Parse)** -> Nhấn **Tải lại danh sách (load)**.
   - *Kết quả:* SnackBar báo: *"Dữ liệu từ máy chủ không đúng định dạng."*.
6. **Kịch bản 5 (Lỗi sập render build - Error Boundary):**
   - Cuộn xuống Card số 3, nhấn nút **Kích hoạt lỗi render trong build**.
   - *Kết quả:* Widget con ném `StateError`. Thay vì sập toàn bộ app thành màn hình đỏ xám, `ErrorWidget.builder` bắt gọn lỗi và vẽ giao diện `ErrorView.compact` màu cam với thông báo: *"Màn hình gặp sự cố khi hiển thị. Hãy quay lại và thử lại."*. Toàn bộ thanh AppBar và các card khác vẫn bấm bình thường. Nhấn lại nút để khôi phục.

#### File code liên quan:
- `lib/presentation/screens/error_simulator_screen.dart`
- `lib/presentation/widgets/simulator_mode_cards.dart`
- `lib/presentation/widgets/simulator_action_cards.dart`
- `lib/presentation/widgets/error_boundary.dart`

#### Câu nói gợi ý của người thuyết minh:
> *"Tiếp theo, em mở bảng Error Simulator để giả lập các sự cố hạ tầng. Khi chuyển sang chế độ Mất mạng, Repository bắt được SocketException và tự động kích hoạt Graceful Degradation: rơi về đọc dữ liệu cache từ SharedPreferences kèm nút Thử lại. Đặc biệt, khi em kích hoạt lỗi render trong build, Error Boundary cô lập hoàn toàn sự cố trong phạm vi widget con, giữ ứng dụng luôn sống sót."*

---

### PHÚT 3:00 – 4:00: LOG VIEWER & STRUCTURED LOGGING
- **Người trình bày:** Sinh viên A (Nguyễn Đức Hải)
- **Mục tiêu:** Chứng minh mọi lỗi (kể cả lỗi lọt lưới) đều được ghi nhận bền vững và có thể kiểm tra trực tiếp trên thiết bị.

#### Các bước thao tác:
1. Tại màn hình Error Simulator, cuộn xuống Card số 4, nhấn nút **Kích hoạt lỗi unhandled async**.
   - *Hiện tượng:* Không hề có try-catch nào ở widget bắt được, nhưng 3-Tier Global Hooks đã tóm được lỗi ở tầng nền tảng và âm thầm đẩy vào `ErrorHandler`.
2. Nhấn biểu tượng quyển sổ (`Icons.history_edu_outlined`) trên AppBar để chuyển sang `LogViewerScreen`.
3. Chỉ vào danh sách các bản ghi lỗi vừa phát sinh được xếp theo thứ tự mới nhất ở trên cùng.
4. Nhấn FilterChip **`[Critical]`** trên thanh lọc để lọc riêng các lỗi nghiêm trọng.
5. Chạm vào bản ghi lỗi `CRITICAL` để mở rộng thẻ chi tiết:
   - Thấy rõ: Mã lỗi (`UNKNOWN_ERROR`), Nguồn gốc (`global`), Thời gian chính xác, và toàn bộ khối **Stack Trace**.
6. Nhấn nút **Sao chép chi tiết** (`TextButton.icon` có icon copy) -> SnackBar xuất hiện: *"Đã sao chép chi tiết lỗi vào bộ nhớ tạm."*.

#### File code liên quan:
- `lib/presentation/screens/log_viewer_screen.dart`
- `lib/presentation/widgets/log_viewer_components.dart`
- `lib/core/error_handling/file_logger.dart`

#### Câu nói gợi ý của người thuyết minh:
> *"Khi có lỗi bất đồng bộ xảy ra ngoài widget tree, 3-Tier Global Safety Net lập tức bắt lấy và tự động leo thang lên mức độ CRITICAL. Toàn bộ thông tin được `FileLogger` ghi tuần tự vào file `app_errors.log`. Tại màn hình Log Viewer, kỹ thuật viên có thể lọc theo mức độ lỗi, mở xem StackTrace chi tiết và bấm sao chép để gửi báo cáo lỗi ngay lập tức."*

---

### PHÚT 4:00 – 5:00: MỞ NHANH 3 ĐOẠN CODE THEN CHỐT (CODE WALKTHROUGH)
- **Người trình bày:** Sinh viên B & Sinh viên A cùng phối hợp
- **Mục tiêu:** Chứng minh tính xác thực và chất lượng Clean Code trực tiếp trên IDE.

#### Thao tác chuyển sang IDE và mở 3 file:

#### 1. File 1: Centralized Error Pipeline 5 bước
- **Đường dẫn:** `lib/core/error_handling/error_handler.dart` (Dòng 42 – 62)
- **Nội dung chỉ vào:** Phương thức `handle(Object error, StackTrace st)` với 5 bước chú thích rõ ràng: Normalize -> Classify -> Log -> Decide Retry -> Translate.
- **Câu nói gợi ý (SV A):**
  > *"Thưa Thầy Cô, đây là trái tim của hệ thống: `ErrorHandler.handle`. Mọi lỗi thô đều được đi qua đúng 5 bước chuẩn hóa, ghi log và dịch sang tiếng Việt trước khi gửi ra giao diện."*

#### 2. File 2: Repository Fallback Cache & Pattern Matching
- **Đường dẫn:** `lib/data/repositories/transaction_repository_impl.dart` (Dòng 57 – 65 và 84 – 98)
- **Nội dung chỉ vào:** Hàm `_shouldFallbackToCache` sử dụng Dart 3 pattern matching kiểm tra `NetworkException`, `TimeoutException`, `ServerException >= 500`.
- **Câu nói gợi ý (SV B):**
  > *"Tại Repository, chúng em hiện thực hóa hợp đồng trừu tượng của Domain. Khối catch bắt lỗi remote và kiểm tra qua `_shouldFallbackToCache`, nếu đúng lỗi mạng thì lập tức đọc cache từ `_localDataSource` để trả về `Success`."*

#### 3. File 3: Factory Pattern phân loại lỗi thô
- **Đường dẫn:** `lib/core/errors/exception_factory.dart` (Dòng 42 – 85)
- **Nội dung chỉ vào:** Phương thức static `ExceptionFactory.from(Object error)` với tham số kiểu `Object error` tuyệt đối không dùng `dynamic`.
- **Câu nói gợi ý (SV A):**
  > *"Và đây là `ExceptionFactory.from`, toàn bộ lỗi hệ thống như `SocketException`, `TimeoutException`, hay `HttpStatusError` đều được chuẩn hóa thành sealed class `AppException`, đảm bảo an toàn kiểu dữ liệu tuyệt đối."*

---

## 🛡️ PHƯƠNG ÁN DỰ PHÒNG XỬ LÝ SỰ CỐ (CONTINGENCY PLANS)

| Tình huống sự cố | Biểu hiện | Cách xử lý tức thời của nhóm |
| :--- | :--- | :--- |
| **1. Emulator bị đơ / treo máy** | Máy ảo Android không phản hồi thao tác click chuột. | **Chuyển sang bản Desktop:** Bật ngay Terminal gõ `flutter run -d windows` (hoặc macOS). Ứng dụng chạy trực tiếp native trên Windows, khởi động chỉ mất 3 giây và chạy cực mượt. |
| **2. Phòng thi mất mạng Internet** | Giảng viên lo lắng app không chạy được do mất kết nối mạng. | **Trấn an tự tin:** Báo cáo với Giảng viên ứng dụng sử dụng kiến trúc `FakeRemoteDataSource` In-Memory, hoàn toàn không phụ thuộc Internet bên ngoài, mọi kịch bản lỗi mạng đều được mô phỏng trung thực 100%. |
| **3. Thao tác nhầm chế độ lỗi** | Danh sách báo lỗi liên tục do quên tắt chế độ giả lập. | Bình tĩnh vào lại **Error Simulator** -> Chọn lại chip **Bình thường (None)** -> Nhấn **Tải lại danh sách (load)**. |
| **4. Máy tính gặp sự cố phần cứng đột ngột** | Máy tính thuyết trình bị sập nguồn hoặc không lên màn hình chiếu. | Nhóm đã chuẩn bị sẵn **Video quay màn hình 5 phút Full HD** (lưu đồng thời trên USB cá nhân và link Google Drive dự phòng) để cắm vào máy tính hội đồng trình chiếu ngay. |

---

## ❓ DANH SÁCH "NẾU HỎI THÌ MỞ FILE NÀO" (8 CÂU HỎI THƯỜNG GẶP)

Khi Giảng viên đặt câu hỏi phản biện, sinh viên giữ bình tĩnh, đọc to tên file và mở đúng vị trí mã nguồn theo bảng sau:

### 1. "Làm sao chứng minh tầng Domain hoàn toàn độc lập, không phụ thuộc Flutter hay Data?"
- **Mở file:** `lib/domain/entities/transaction.dart` và `lib/domain/usecases/add_transaction.dart`.
- **Vị trí chỉ:** Phần đầu file (dòng 1 – 10).
- **Giải thích:** Toàn bộ phần `import` chỉ có các file nội bộ trong thư mục `domain/` và `core/errors/`, tuyệt đối không có `package:flutter`, không có `lib/data`.

### 2. "Dữ liệu được lưu trữ offline như thế nào và khi nào thì đồng bộ?"
- **Mở file:** `lib/data/datasources/local_cache_data_source.dart` (dòng 25 – 45) và `lib/data/repositories/transaction_repository_impl.dart` (dòng 72 – 82).
- **Giải thích:** Dữ liệu cache được tuần tự hóa thành JSON và lưu vào `SharedPreferences`. Khi hàm `getAll()` lấy dữ liệu từ remote thành công, nó tự động gọi `_localDataSource.replaceAll()` để đồng bộ đè dữ liệu mới nhất vào cache.

### 3. "Nếu nhiều luồng cùng ghi log một lúc thì file có bị lỗi lẫn dòng không?"
- **Mở file:** `lib/core/error_handling/file_logger.dart` (dòng 45 – 55).
- **Giải thích:** `FileLogger` sử dụng biến `Future<void> _lock` để xây dựng hàng đợi khóa tuần tự (Sequential Future Queue / Mutex). Mọi thao tác ghi log đều phải chờ Future trước đó hoàn thành mới được ghi tiếp.

### 4. "Cơ chế nào bắt được lỗi giao diện khi đang render build()?"
- **Mở file:** `lib/core/error_handling/error_widget_setup.dart` (dòng 20 – 35) và `lib/presentation/widgets/error_boundary.dart`.
- **Giải thích:** Hàm `installErrorWidgetBuilder()` thiết lập `ErrorWidget.builder` toàn cục, trả về `ErrorView.compact` khi xảy ra crash render; kết hợp với `ErrorBoundary` lắng nghe state lỗi qua `ValueListenable`.

### 5. "Nếu usecase bên dưới ném lỗi bất ngờ thì Notifier có bị treo cờ isSubmitting không?"
- **Mở file:** `lib/presentation/state/transaction_notifier.dart` (dòng 162 – 199).
- **Giải thích:** Hàm `_run()` bao bọc toàn bộ usecase trong khối `try-catch-finally`. Khối `finally` đảm bảo 100% dòng lệnh `_isSubmitting = false` luôn được thực thi kể cả khi xảy ra unhandled error.

### 6. "Tại sao không dùng kiểu dynamic trong ExceptionFactory hay ErrorHandler?"
- **Mở file:** `lib/core/errors/exception_factory.dart` (dòng 42).
- **Giải thích:** `from(Object error)` sử dụng `Object` thay vì `dynamic` để giữ trọn vẹn khả năng kiểm tra kiểu tĩnh (static type safety) của Dart 3, tránh lỗi gọi phương thức không tồn tại tại runtime.

### 7. "Làm thế nào để phân biệt khi nào hiện SnackBar và khi nào hiện Error Boundary sập màn hình?"
- **Mở file:** `lib/presentation/state/transaction_notifier.dart` (dòng 47 – 54 và 280 – 300).
- **Giải thích:** Phân tách trạng thái rõ ràng: lỗi thao tác form (thêm/sửa thất bại) được đẩy vào `actionError` để hiện SnackBar (giúp người dùng không bị mất dữ liệu đang nhập); chỉ lỗi truy vấn danh sách nghiêm trọng mới đưa vào `boundaryError` để `ErrorBoundary` kích hoạt màn hình lỗi.

### 8. "Độ phủ kiểm thử của dự án thực tế là bao nhiêu và làm sao để kiểm tra ngay tại chỗ?"
- **Mở Terminal:** Chạy lệnh `flutter test`.
- **Mở file:** `README.md` (Mục 6 - Bảng Test Coverage).
- **Giải thích:** Toàn bộ **223/223 tests PASS (100%)**, độ phủ của tầng `lib/domain` đạt **88.64%**, `lib/core/errors` đạt **98.48%**, và `lib/core/error_handling` đạt **97.31%**.

---

*Tài liệu kịch bản demo được phê duyệt và lưu trữ chính thức tại `docs/DEMO_SCRIPT.md`.*
