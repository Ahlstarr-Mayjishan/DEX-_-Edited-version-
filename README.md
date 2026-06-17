# DarkDEX++ Premium & Local Helper Server

Bản nâng cấp DarkDEX++ tích hợp 4 công cụ phân tích cao cấp và **C++ Local Helper Server** để tối ưu hóa hiệu năng, giảm lag tối đa khi xử lý code lớn.

---

## 🚀 Hướng Dẫn Sử Dụng nhanh (Quick Start)

### Bước 1: Khởi động Local Helper Server
1. Truy cập thư mục `HelperServer`.
2. Chạy file **`DEX_Helper.exe`**. Một cửa sổ Console nhỏ sẽ xuất hiện hiển thị:
   ```text
   DEX++ C++ Local Helper Server listening on port 8080...
   ```
   *Lưu ý: Bạn phải chạy thủ công file này vì các Roblox Executor bị giới hạn sandbox bảo mật, không thể tự khởi động file chạy của Windows.*

### Bước 2: Thực thi script trong Game
1. Mở file [DEX++_compiled.luau](file:///d:/Scripting/Rework%20DarkDEX++/DEX++_compiled.luau) và sao chép toàn bộ code bên trong.
2. Dán vào Roblox Executor của bạn và nhấn **Execute**.
3. Khi bạn sử dụng tính năng **Decompiler** hoặc **Property Tracker**, script sẽ tự động giao tiếp với C++ Helper Server để xử lý mượt mà nhất.

> [!TIP]
> **Chế độ tự động Fallback (Fail-Safe):** Nếu bạn không mở `DEX_Helper.exe`, script vẫn chạy bình thường! DarkDEX++ sẽ tự động chuyển sang chế độ xử lý bằng Luau nguyên bản mà không bị lỗi hay crash.

---

## 🛠️ Biên dịch lại Helper Server (Dành cho Lập trình viên)

Nếu bạn thay đổi code C++ trong [HelperServer/main.cpp](file:///d:/Scripting/Rework%20DarkDEX++/HelperServer/main.cpp) và muốn biên dịch lại:
1. Chạy file [HelperServer/compile.bat](file:///d:/Scripting/Rework%20DarkDEX++/HelperServer/compile.bat).
2. Script sẽ sử dụng trình biên dịch `g++` để tạo lại file `DEX_Helper.exe` tối ưu hóa cao (`-O3`).

Nếu bạn thay đổi các file Module Luau trong thư mục `Modules/`:
1. Chạy command: `python build.py` để đóng gói lại toàn bộ code thành file [DEX++_compiled.luau](file:///d:/Scripting/Rework%20DarkDEX++/DEX++_compiled.luau).

---

## 💎 Tổng quan 4 tính năng Premium mới tích hợp

### 1. Auto Exploit / Remote Fuzzer Generator
* **Cách dùng:** Click chuột phải vào bất kỳ `RemoteEvent`, `RemoteFunction` nào trong Explorer -> Chọn **Generate Fuzzer Script**.
* **Chức năng:** Tự động tạo một template script exploit mẫu để fuzzing remote đó với các giá trị biên (NaN, Infinity, nested tables, v.v.). Code mẫu sẽ tự động hiển thị trong cửa sổ Script Viewer.

### 2. Property Tracker / Instance Watcher
* **Cách dùng:** Nhấp chuột phải vào Instance -> Chọn **Track Properties** hoặc mở từ bảng điều khiển chính.
* **Chức năng:** Theo dõi các thay đổi thuộc tính thời gian thực. Hỗ trợ lọc tìm kiếm và xuất log. Các log này đồng thời được gửi về C++ Server để lưu trữ vào file `dex_server_logs.txt` trên máy tính của bạn.

### 3. Luau Code Generator / Instance Serializer
* **Cách dùng:** Click chuột phải vào bất kỳ cụm Instance nào -> Chọn **Serialize to Luau**.
* **Chức năng:** Chuyển đổi toàn bộ cây Object và các thuộc tính tương thích thành code Luau thuần túy để tái tạo lại cấu trúc đó (hữu ích khi build lại map/UI).

### 4. Active Thread & Script Manager
* **Cách dùng:** Mở ứng dụng từ màn hình grid chính của DarkDEX++.
* **Chức năng:**
  * **Tab Scripts:** Quản lý bật/tắt (Enable/Disable) hoặc decompile các Script đang hoạt động.
  * **Tab Coroutines:** Quét bộ nhớ Luau Registry để liệt kê các luồng (thread) đang chạy/tạm dừng, cho phép theo dõi stack debug và tắt (`task.cancel`) các luồng bị treo để giải phóng tài nguyên.

---

## 📂 Cấu trúc thư mục dự án

* `DEX++.luau`: File loader chính.
* `DEX++_compiled.luau`: Bản build hoàn chỉnh sau khi đóng gói toàn bộ module (Dùng bản này để chạy).
* `build.py`: Script Python để đóng gói các module trong `Modules/` và `Plugins/` vào file đích.
* `Modules/`: Thư mục chứa code logic của từng tính năng độc lập.
* `HelperServer/`:
  * `main.cpp`: Code máy chủ C++ tối ưu hóa deobfuscate và ghi log.
  * `compile.bat`: File batch hỗ trợ tự động biên dịch code C++.
  * `DEX_Helper.exe`: File chạy Windows của server helper.
  * `dex_server_logs.txt`: File chứa log thuộc tính được lưu trữ.
