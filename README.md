# FitnessCenter App

- **Môn học:** Công nghệ phần mềm
- **Tên đề tài:** Ứng dụng quản lý phòng gym
- **Nhóm:** 4
- **Tên nhóm:** Mặt trời nho nhỏ

---

## 1. Yêu cầu

Cài đặt các công cụ sau:

- [Node.js](https://nodejs.org/) (khuyên dùng bản LTS)
- Git
- Tải ứng dụng **Expo Go** trên điện thoại iOS hoặc Android
  *(Expo là framework & bộ công cụ hỗ trợ phát triển, chạy thử và build ứng dụng React Native nhanh chóng).*

## 2. Bắt đầu dự án

Mở Terminal và thực hiện:

### Lần đầu tiên (Clone dự án)

```bash
git clone https://github.com/ThNhan311/Mat_troi_nho_nho.git
cd Mat_troi_nho_nho
```

### Các lần sau (Cập nhật code mới nhất)

```bash
git pull origin main
```

## 3. Cài đặt thư viện

```bash
npm install
```

## 4. Chạy project

```bash
npx expo start
```

Sau khi Expo khởi động:

- Nhấn `w` để chạy trên trình duyệt Web hoặc quét mã QR bằng ứng dụng **Expo Go** trên điện thoại.

> **Mẹo:** Nếu app không nhận biến môi trường (`.env`), hãy xóa cache và khởi động lại:
> ```bash
> npx expo start -c
> ```

## 5. Quy trình làm việc với Git

Không làm việc trực tiếp trên branch `main`. Mỗi thành viên tạo branch riêng:

```bash
git checkout main
git pull origin main
git checkout -b feature/ten-chuc-nang
```

Ví dụ:

```bash
git checkout -b feature/login
```

Sau khi hoàn thành công việc:

```bash
git add .
git commit -m "Add login screen"
git push -u origin feature/login
```

Sau đó tạo Pull Request trên GitHub để đưa code vào branch `main`.

Trước khi bắt đầu một công việc mới, luôn cập nhật branch `main`:

```bash
git checkout main
git pull origin main
```