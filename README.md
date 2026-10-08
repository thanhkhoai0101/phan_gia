# Phan Family - Ứng Dụng Quản Lý Gia Đình

**Phan Family** là một ứng dụng di động được xây dựng bằng **Flutter** và **Firebase** nhằm giúp các gia đình hiện đại quản lý các công việc hàng ngày một cách thông minh, gọn gàng và tiện lợi. 

Từ việc lên thực đơn ăn uống, đi chợ, quản lý chi tiêu cho đến phân công việc nhà, mọi thứ đều được tích hợp trong một ứng dụng duy nhất.

---

## 🌟 Các Tính Năng Nổi Bật

### 1. 🍽️ Nội Trợ & Nấu Ăn (Household & Meals)
- **Hôm nay ăn gì?**: Bốc ngẫu nhiên thực đơn cho gia đình khi bạn không biết phải nấu món gì, hoặc tự chọn từ danh sách món ăn.
- **Quản lý Món Ăn**: 
  - Xem danh sách toàn bộ món ăn được phân loại trực quan (Thịt heo, bò, gà, hải sản, chay, v.v.).
  - Thêm món ăn mới với đầy đủ thông tin: nguyên liệu, cách nấu, định lượng và giá dự kiến.
  - Nhấn để đưa món ăn vào "Thực đơn hôm nay" một cách nhanh chóng.
- **Đánh giá món ăn**: Lưu lại đánh giá (rating 1-5 sao) và ghi chú sau mỗi bữa ăn (vd: "Cho ít muối", "Lần sau thêm ớt").
- **Chế độ Nấu Ăn (Cooking Mode)**: Có thể linh hoạt bật/tắt trong phần Cài đặt. Khi tắt, giao diện sẽ được tối giản hoá chỉ để tập trung vào thực đơn món ăn hôm nay.

### 2. 🛒 Đi Chợ & Tài Chính (Shopping & Finance)
- **Danh sách đi chợ**: Tạo danh sách các nguyên liệu cần mua với chi phí dự kiến, phân công cho các thành viên trong nhà.
- **Ghi nhận chi tiêu**: Sau khi đi chợ xong, lưu lại số tiền thực tế đã chi để hệ thống tự động ghi nhận giao dịch.
- **Thống kê Chi tiêu (Weekly Finance)**: 
  - Theo dõi tổng số tiền đã chi trong tuần so với ngân sách.
  - Biểu đồ cột trực quan theo 7 ngày trong tuần.
  - Lịch sử các giao dịch chi tiết.

### 3. 📝 Quản Lý Việc Nhà (Tasks)
- Tạo và phân công các công việc nhà (dọn dẹp, rửa bát, đổ rác, v.v.).
- Theo dõi tiến độ công việc, ai đã hoàn thành và quản lý điểm thưởng (points).

### 4. 💬 Kết Nối Gia Đình (Feed & Chat)
- **Mạng xã hội thu nhỏ (Feed)**: Chia sẻ những khoảnh khắc, hình ảnh và trạng thái lên bảng tin chung để cả nhà cùng xem và tương tác.
- **Nhắn tin (Chat)**: Trò chuyện riêng tư hoặc theo nhóm, giúp mọi người dễ dàng liên lạc và trao đổi thông tin.

### 5. 🎮 Giải Trí (Entertainment - Game Hub)
- Góc giải trí tích hợp ngay trong ứng dụng với các trò chơi nhỏ giúp các thành viên thư giãn sau giờ học tập, làm việc hoặc cùng nhau thi tài để tăng sự gắn kết.

### 6. ⚙️ Hệ Thống Tài Khoản
- Đăng nhập/Đăng ký an toàn qua Firebase Authentication.
- Thông tin cá nhân hoá và cài đặt riêng tư cho từng thành viên (như bật/tắt Chế độ Nấu ăn).

---

## 🚀 Hướng Dẫn Cài Đặt & Sử Dụng

### Yêu Cầu Hệ Thống
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (phiên bản mới nhất)
- Cài đặt cấu hình môi trường Android / iOS (Xcode, Android Studio).
- Đã thiết lập Firebase cho dự án (bạn cần có file `google-services.json` cho Android và `GoogleService-Info.plist` cho iOS).

### Khởi Chạy Ứng Dụng
1. Clone dự án về máy:
   ```bash
   git clone <repo_url>
   cd phan_family
   ```
2. Cài đặt các thư viện phụ thuộc:
   ```bash
   flutter pub get
   ```
3. Cấu hình Cloudinary (Dùng cho upload hình ảnh):
   - Đổi tên file `lib/config/cloudinary_base_config.dart` thành `lib/config/cloudinary_config.dart`.
   - Mở file vừa đổi tên và cập nhật các thông số tài khoản Cloudinary của bạn:
     ```dart
     class CloudinaryConfig {
       static const String cloudName  = 'YOUR_CLOUD_NAME';
       static const String uploadPreset = 'YOUR_UPLOAD_PRESET';
       static const String apiKey    = 'YOUR_API_KEY';
       static const String apiSecret  = 'YOUR_API_SECRET';
     }
     ```
4. Chạy ứng dụng trên thiết bị ảo hoặc thật:
   ```bash
   flutter run
   ```

*(Ghi chú: Có thể sử dụng phím `r` trên terminal để **hot reload** sau khi lưu code)*

---

## 🏗️ Kiến Trúc Dự Án
Ứng dụng áp dụng mô hình **Bloc Pattern** kết hợp với kiến trúc Service-Repository để tách biệt giao diện UI và logic:
- `lib/blocs/`: Quản lý state chung (Auth, Theme).
- `lib/features/`: Mỗi tính năng lớn (household, tasks...) được đóng gói thành các module riêng biệt chứa màn hình (screens), mô hình dữ liệu (models), state (bloc) và service (giao tiếp với Firebase).
- `lib/models/`: Chứa các model cốt lõi.
- `lib/services/`: Các dịch vụ cốt lõi (Firebase, Notification...).

