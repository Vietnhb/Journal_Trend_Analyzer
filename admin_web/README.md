# Journal Trend Admin Web

Trang quản trị độc lập viết bằng Flutter Web cho Firebase project
`journal-trend-analyzer`. Đây không phải phần web của ứng dụng mobile và không
yêu cầu sửa source Android/iOS hiện có.

## Firebase

Firebase Web App đã được đăng ký trong chính project đang dùng cho mobile:

- Project ID: `journal-trend-analyzer`
- Auth domain: `journal-trend-analyzer.firebaseapp.com`
- Hosting target: `admin`
- API production: cùng origin tại `/api/v1`

Không tạo Firebase project thứ hai. Firebase Web config là định danh public của
app; quyền quản trị thực tế được bảo vệ bằng Firebase Authentication, custom
claim `admin: true` và `adminApi`.

## Yêu cầu

- Flutter/Dart tương thích SDK ghi trong `pubspec.yaml`
- Chrome để chạy local
- Node.js 22 cho `../functions`
- Firebase CLI cho emulator và deploy

## Chạy local

Chạy Functions và Hosting Emulator từ repository root:

```powershell
npx firebase-tools emulators:start --only functions,hosting
```

Sau đó mở `http://localhost:5000`. Khi chạy trên localhost, UI gọi trực tiếp
Functions Emulator tại cổng `5001`. Bản production vẫn gọi `/api/v1` cùng
origin qua Hosting rewrite.

Kiểm tra mã Flutter từ thư mục `admin_web`:

```powershell
flutter pub get
flutter analyze
flutter test
```

Chỉ truyền `API_BASE_URL` khi tích hợp với một gateway/staging origin khác.

Chrome có thể ghi cảnh báo `Cross-Origin-Opener-Policy ... window.closed` khi
dùng `flutter run`; đây là cảnh báo của dev server khi Firebase Auth kiểm tra
popup. Bản chạy qua Firebase Hosting/Hosting Emulator dùng header
`same-origin-allow-popups` trong `firebase.json`.

Nếu đã đăng ký App Check reCAPTCHA Enterprise:

```powershell
flutter run -d chrome `
  --dart-define=APP_CHECK_SITE_KEY=PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY
```

Site key được đóng gói vào trình duyệt và không phải secret. Không đưa service
account JSON, access token hoặc private key vào Dart source hay `--dart-define`.

## Build production

Từ repository root:

```powershell
dart run tool/build_admin_web.dart
```

Script chạy trong đúng thư mục `admin_web` và thực thi:

```powershell
flutter build web --release --csp --no-web-resources-cdn
```

Artifact nằm ở `admin_web/build/web`. Nếu cần App Check trong predeploy:

```powershell
$env:APP_CHECK_SITE_KEY='PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY'
$env:API_BASE_URL='/api/v1'
dart run tool/build_admin_web.dart
```

Hai biến trên chỉ được script chuyển thành Dart defines; chúng không phải cấu
hình backend.

## Cấp quyền Admin

User phải tồn tại trong Firebase Authentication trước. Từ repository root:

```powershell
npm --prefix functions ci
npm --prefix functions run set-admin -- `
  --email admin@example.com `
  --project journal-trend-analyzer
```

Đăng xuất rồi đăng nhập lại để Firebase phát ID token mới chứa claim.

## Deploy

`firebase.json` build Flutter Web tự động trước khi deploy Hosting:

```powershell
npx firebase-tools deploy --only functions:adminApi,hosting:admin `
  --project journal-trend-analyzer
```

Hướng dẫn đầy đủ về Firebase services, backend parameters, emulator, Rules,
Remote Config và rollback nằm tại
[`../ADMIN_WEB_SETUP.md`](../ADMIN_WEB_SETUP.md).
