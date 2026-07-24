# Thiết lập và triển khai Flutter Admin Web

Admin Web là một Flutter Web project độc lập tại `admin_web/`. Ứng dụng
Android/iOS hiện tại không bị sửa và vẫn sử dụng Firebase như trước. Trình duyệt
chỉ thực hiện đăng nhập; mọi thao tác đặc quyền đi qua Cloud Function
`adminApi` tại region `asia-southeast1`.

## 1. Không tạo Firebase project mới

Firebase Web App đã được đăng ký bằng cấu hình do chủ project cung cấp trong
chính project đang dùng cho mobile:

- Project ID: `journal-trend-analyzer`
- Auth domain: `journal-trend-analyzer.firebaseapp.com`
- Storage bucket: `journal-trend-analyzer.firebasestorage.app`
- App ID: `1:48277052775:web:af916acc2500cdd79263c2`
- Measurement ID: `G-NVP7Y9P21P`

Không bấm tạo thêm Firebase project hoặc Android app. Nếu cần kiểm tra Web App,
vào **Firebase Console → Project settings → General → Your apps** và chọn app
có biểu tượng `</>`.

Firebase Web API key, App ID và reCAPTCHA site key là cấu hình public được đóng
gói vào browser. Chúng không cấp quyền Admin. Không đưa service-account JSON,
private key, refresh token, access token hoặc backend secret vào Dart source,
Git hay `--dart-define`.

## 2. Kiến trúc và ranh giới tin cậy

```text
Flutter Admin Web
  ├─ Firebase Authentication: Google Sign-In
  ├─ Firebase App Check: reCAPTCHA Enterprise, tùy chọn
  └─ /api/v1/**
       └─ Firebase Hosting rewrite
            └─ adminApi (Cloud Functions v2, Node.js 22)
                 ├─ verify ID token + kiểm tra admin=true
                 ├─ Firebase Auth Admin SDK
                 ├─ Firebase Storage Admin SDK
                 ├─ Firebase Remote Config Admin SDK
                 ├─ Firebase Cloud Messaging Admin SDK
                 ├─ BigQuery Google Analytics export
                 ├─ BigQuery Crashlytics export
                 └─ Firestore admin_audit_logs
```

Các thành phần:

- `admin_web/`: Flutter Web UI; artifact ở `admin_web/build/web`.
- `functions/`: API tin cậy chạy Node.js 22.
- `tool/build_admin_web.dart`: build Flutter từ đúng subdirectory.
- `firebase.json`: build predeploy, Hosting, rewrites, emulator và headers.
- `storage.rules`: user chỉ CRUD PDF của chính mình.
- `firestore.rules`: browser không được ghi audit.
- `remoteconfig.template.json`: baseline `max_journals`, `max_keywords`.

Ẩn menu hoặc chặn route trong Flutter chỉ là UX. Backend luôn kiểm tra Firebase
ID token đã revoke và custom claim:

```json
{ "admin": true }
```

## 3. Điều kiện cần

- Flutter/Dart tương thích SDK trong `admin_web/pubspec.yaml`.
- Chrome để chạy Flutter Web local.
- Node.js `22.x` và npm cho `functions/`.
- Firebase CLI hỗ trợ Functions Node.js 22.
- Java 21 nếu chạy đầy đủ Local Emulator Suite.
- `gcloud` nếu dùng Application Default Credentials ở máy local.
- Quyền phù hợp trên project `journal-trend-analyzer`.
- Gói Blaze cho Cloud Functions và các API Google Cloud production liên quan.

Kiểm tra:

```powershell
flutter --version
dart --version
node --version
npm --version
npx firebase-tools --version
```

## 4. Cấu hình Firebase Console

Trong đúng project `journal-trend-analyzer`:

1. **Authentication → Sign-in method**: bật Google.
2. **Authentication → Settings → Authorized domains**: đảm bảo có
   `localhost`, `journal-trend-analyzer-admin.web.app` và
   `journal-trend-analyzer-admin.firebaseapp.com`. Thêm custom domain nếu dùng.
3. Firestore: dùng Native mode cho `admin_audit_logs`.
4. Storage: giữ bucket/path mobile hiện có
   `report/{uid}/analysis/{filename}.pdf`.
5. Cloud Messaging: bật FCM HTTP v1.
6. Analytics: liên kết GA4, lấy numeric Property ID, sau đó trong
   **Project settings → Integrations → BigQuery** bật export Google Analytics.
7. Crashlytics: bật BigQuery export nếu cần Crash Analyzer.
8. App Check: đăng ký Web App với reCAPTCHA Enterprise trước khi enforcement.

Crashlytics trên dashboard đọc BigQuery export, nên dữ liệu có
độ trễ. Backend tự phát hiện dataset/table; GA4 ưu tiên bảng daily để không đếm
trùng với bảng intraday cùng ngày.

Service account chạy Function cần quyền tối thiểu cho những tính năng được bật:
quản lý Firebase Auth, Remote Config, report bucket, ghi Firestore audit, gửi
FCM, chạy BigQuery query và đọc các dataset export. Tài khoản bật Analytics
export lần đầu cần quyền Editor/Administrator trên GA4 Property; backend không
cần OAuth scope `analytics.readonly`.

## 5. Flutter Web build configuration

Hai Dart defines được hỗ trợ:

| Define | Mặc định | Mục đích |
|---|---|---|
| `API_BASE_URL` | `/api/v1` cùng origin | Hosting rewrite xác định Function/project/region; không hard-code URL |
| `APP_CHECK_SITE_KEY` | rỗng | Public reCAPTCHA Enterprise site key |

Chạy local từ repository root:

```powershell
npx firebase-tools emulators:start --only functions,hosting
```

Mở `http://localhost:5000`. Nếu cần build với App Check đã đăng ký:

```powershell
flutter run -d chrome `
  --dart-define=APP_CHECK_SITE_KEY=PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY
```

Không đặt backend secret trong Dart define: mọi define đều có thể bị người dùng
đọc từ bundle web.

Build production chuẩn từ repository root:

```powershell
dart run tool/build_admin_web.dart
```

Script chạy lệnh sau trong `admin_web/`:

```powershell
flutter build web --release --csp --no-web-resources-cdn
```

`--no-web-resources-cdn` giữ CanvasKit/WebAssembly trong Hosting artifact thay
vì tải runtime từ CDN. Artifact nằm ở `admin_web/build/web`.

Khi Firebase predeploy cần App Check:

```powershell
$env:API_BASE_URL='/api/v1'
$env:APP_CHECK_SITE_KEY='PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY'
dart run tool/build_admin_web.dart
```

Build script tự chuyển hai biến này thành `--dart-define`. Nếu không đặt biến,
mọi môi trường mặc định dùng `/api/v1` cùng origin qua Hosting rewrite, và App
Check không được activate.

## 6. Cấu hình backend

Cloud Functions tự nhận Application Default Credentials trên Firebase. Không
upload service-account JSON vào `functions/`.

Các parameter:

```dotenv
ENFORCE_APP_CHECK=false
ADMIN_ALLOWED_ORIGINS=https://journal-trend-analyzer-admin.web.app,https://journal-trend-analyzer-admin.firebaseapp.com
GA4_PROPERTY_ID=
CRASHLYTICS_TABLE=project_id.dataset_id.table_id
```

- `ENFORCE_APP_CHECK`: chỉ đổi sang `true` sau khi Flutter Web đã gửi token hợp
  lệ và đã smoke test.
- `ADMIN_ALLOWED_ORIGINS`: exact origins, phân tách bằng dấu phẩy; không wildcard.
- `GA4_PROPERTY_ID`: numeric property ID mà admin web đọc qua Google Analytics
  Data API. Mỗi admin cấp scope `analytics.readonly` bằng OAuth khi kết nối
  Analytics; backend không dùng service account để đọc GA4.
- `CRASHLYTICS_TABLE`: dạng `project.dataset.table`.

GA4/Crashlytics có thể để trống lúc đầu. API sẽ trả trạng thái
`unconfigured`, không làm hỏng toàn dashboard.

Khi chạy local với tài nguyên Google thật:

```powershell
gcloud auth application-default login --scopes=https://www.googleapis.com/auth/cloud-platform
$env:GOOGLE_CLOUD_PROJECT='journal-trend-analyzer'
```

Không trỏ `GOOGLE_APPLICATION_CREDENTIALS` tới file key nằm trong repository.
Trong CI nên dùng Workload Identity Federation thay cho key JSON dài hạn.

## 7. Bootstrap Admin đầu tiên

Firebase Console không có UI đặt custom claims.

1. Cho tài khoản Admin đăng nhập Google một lần để Firebase Auth tạo user.
2. Đăng nhập ADC bằng credential tin cậy.
3. Chạy một trong hai lệnh:

```powershell
npm --prefix functions ci
npm --prefix functions run set-admin -- `
  --email admin@example.com `
  --project journal-trend-analyzer
```

hoặc:

```powershell
npm --prefix functions run set-admin -- `
  --uid FIREBASE_UID `
  --project journal-trend-analyzer
```

`--project` là bắt buộc để tránh cấp quyền nhầm. Script merge với custom claims
hiện hữu thay vì ghi đè. Sau đó đăng xuất và đăng nhập lại Flutter Admin Web để
nhận ID token mới.

Thu hồi bằng tùy chọn `--revoke`; script bảo vệ Admin active cuối cùng và revoke
refresh token. Không tạo endpoint public kiểu “make me admin”.

## 8. Kiểm tra trước deploy

```powershell
npm --prefix functions ci
npm --prefix functions run typecheck
npm --prefix functions run lint
npm --prefix functions test
npm --prefix functions run build

Set-Location admin_web
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
Set-Location ..

dart run tool/build_admin_web.dart
```

Không commit `admin_web/build/`, `admin_web/.dart_tool/`, `.env*`, credential
hoặc Firebase debug logs.

## 9. Emulator và chạy local

Khởi động backend/Hosting emulator:

```powershell
npx firebase-tools emulators:start --only functions,hosting
```

Chạy Flutter trong terminal khác. Client nhận biết `localhost` và tự gọi
Function emulator:

```powershell
Set-Location admin_web
flutter run -d chrome
```

Luồng mặc định vẫn dùng Firebase Google Auth thật. Function emulator có thể
chạm tài nguyên thật khi ADC cho phép, vì vậy chỉ thử mutation trên project
staging/test. Nếu muốn nối client vào Auth Emulator, thêm
`--dart-define=USE_AUTH_EMULATOR=true` và tự tạo/cấp claim Admin cho user trong
Auth Emulator.

Khi chạy bằng `flutter run`, Chrome có thể ghi cảnh báo
`Cross-Origin-Opener-Policy ... window.closed` do dev server không dùng header
Hosting. Cảnh báo này không phải lỗi API. Bản Hosting và Hosting Emulator dùng
`same-origin-allow-popups` từ `firebase.json`.

Để compile/test Rules và backend với bộ emulator riêng:

```powershell
npx firebase-tools emulators:start `
  --only auth,firestore,functions,hosting,storage
```

Không kỳ vọng Analytics, Remote Config hoặc Crashlytics/BigQuery có emulator đầy
đủ. Dùng mock hoặc project staging cho các integration này.

## 10. Security Rules

### Storage

| Chủ thể | Report của mình | Report user khác |
|---|---|---|
| User đăng nhập | list/read/create/update/delete | từ chối |
| Admin browser | quyền owner như user | không truy cập trực tiếp; dùng `adminApi` |
| Chưa đăng nhập | từ chối | từ chối |

Owner upload dưới 10 MiB, tên `.pdf`, MIME `application/pdf`. Admin SDK bypass
Rules nhưng backend vẫn validate path, MIME, size, encoding, generation và chữ
ký byte `%PDF-`; mọi
mutation được audit.

### Firestore

- Collection audit: `admin_audit_logs`.
- Admin client chỉ được read/list tối đa 100 document.
- Browser/mobile không được create/update/delete audit.
- Collection khác mặc định deny.
- `adminApi` ghi audit bằng Admin SDK.

Kiểm tra tối thiểu:

1. Owner vẫn CRUD report đúng UID.
2. User và Admin client không đọc report của UID khác.
3. Cross-user report chỉ đi qua `adminApi`.
4. User thường không đọc audit.
5. Admin query audit phải có `limit <= 100`.
6. Không client nào ghi audit trực tiếp.

## 11. Remote Config

Baseline trong repo:

- `max_journals = 10`
- `max_keywords = 12`

> Trước khi deploy Remote Config, phải export template production hiện tại,
> merge hai key của repo vào bản đầy đủ và review diff. Deploy thẳng template
> baseline có thể xóa parameter/condition production khác.

Nếu chưa merge, bỏ `remoteconfig` khỏi lệnh deploy. Admin Web API dùng ETag để
tránh ghi đè thay đổi đồng thời và giữ những parameter/condition khác.

## 12. Firebase Hosting

Admin Web dùng Hosting target `admin`, mặc định ánh xạ tới site
`journal-trend-analyzer-admin`.

Nếu site chưa tồn tại:

```powershell
npx firebase-tools hosting:sites:create journal-trend-analyzer-admin `
  --project journal-trend-analyzer
npx firebase-tools target:apply hosting admin journal-trend-analyzer-admin `
  --project journal-trend-analyzer
```

`firebase.json` có:

- public directory `admin_web/build/web`;
- predeploy `dart run tool/build_admin_web.dart`;
- `/api/**` rewrite tới `adminApi` trước SPA fallback;
- các route còn lại về `/index.html`;
- không cache HTML/bootstrap/service worker/main bundle;
- cache có revalidation cho Flutter assets và immutable cho CanvasKit;
- COOP `same-origin-allow-popups` cho Google Sign-In;
- CSP, HSTS, `nosniff`, frame, referrer và permissions policy.

FlutterFire Web tự inject inline module loader khi bootstrap. Vì vậy CSP cần
`script-src 'unsafe-inline'`. CanvasKit/WebAssembly cần
`'wasm-unsafe-eval'`. Đây là hai ngoại lệ có chủ đích; không bỏ chúng nếu chưa
kiểm thử lại login và Flutter renderer. CSP cũng chỉ mở các Google/Firebase
connect, frame và image origins cần cho Auth, App Check và avatar.

## 13. Deploy theo từng lớp

Đăng nhập và chọn đúng project:

```powershell
npx firebase-tools login
npx firebase-tools use journal-trend-analyzer
```

Deploy:

```powershell
npx firebase-tools deploy --only firestore,storage `
  --project journal-trend-analyzer

# Chỉ chạy sau khi đã export/merge/review template production đầy đủ:
npx firebase-tools deploy --only remoteconfig `
  --project journal-trend-analyzer

npx firebase-tools deploy --only functions:adminApi `
  --project journal-trend-analyzer

$env:API_BASE_URL='/api/v1'
# Chỉ đặt dòng sau nếu App Check Web đã cấu hình:
# $env:APP_CHECK_SITE_KEY='PUBLIC_RECAPTCHA_ENTERPRISE_SITE_KEY'
npx firebase-tools deploy --only hosting:admin `
  --project journal-trend-analyzer
```

Deploy Function trước Hosting để `/api/**` không trỏ tới Function chưa tồn tại.
Mỗi URL Firebase Hosting được deploy là production.

## 14. Production checklist

- Flutter format/analyze/test/build đều pass.
- Functions typecheck/lint/test/build đều pass trên Node.js 22.
- Không có `.env`, service account hoặc credential trong Git/artifact.
- Google provider và Authorized domains đúng.
- Admin đầu tiên có claim và đã đăng nhập lại.
- User thường nhận 403 từ API.
- Self-disable, self-demote, self-delete và thao tác lên Admin cuối bị chặn.
- Mobile vẫn đọc Remote Config và CRUD report của chính UID.
- Audit có actor/action/target/time.
- GA4/BigQuery thiếu config chỉ hiện “chưa cấu hình”.
- FCM yêu cầu màn hình xác nhận.
- Chỉ bật App Check enforcement sau khi production token hoạt động.

## 15. Giới hạn hiện tại

- Mobile chưa lưu FCM token lên cloud/chưa subscribe topic; web chỉ gửi test tới
  token hoặc FID nhập thủ công.
- Bookmarks, recent searches và notification center của mobile là local/in-memory.
- OpenAlex không phải Firebase collection để Admin CRUD.
- Analytics và Crashlytics BigQuery không realtime.
- Download token PDF đã phát hành vẫn là bearer URL cho tới khi token bị rotate
  hoặc object bị xóa; Admin API không trả các URL đó.

## 16. Lỗi thường gặp

- **403 sau khi cấp Admin:** đăng xuất/đăng nhập lại hoặc force refresh ID token.
- **Google popup bị chặn:** kiểm tra Authorized domains, CSP, Auth domain và COOP.
- **App Check 401:** tạm giữ `ENFORCE_APP_CHECK=false`, kiểm tra
  `APP_CHECK_SITE_KEY`, sau đó bật enforcement theo từng bước.
- **API local không kết nối:** kiểm tra full Functions emulator URL và CORS.
- **Storage permission denied:** kiểm tra UID, path, `.pdf`, MIME và size.
- **Remote Config 409:** reload để lấy ETag mới rồi xác nhận lại.
- **Google báo “This app is blocked”:** không xin scope Analytics bằng ADC.
  Chỉ dùng `cloud-platform`; bật Analytics export tại Firebase Console rồi để
  backend đọc BigQuery.
- **Analytics chưa có dữ liệu:** kiểm tra BigQuery Integration; lần export đầu
  có thể cần chờ tới lần đồng bộ tiếp theo.
- **Crash Analyzer trống:** kiểm tra BigQuery export, table ID, location và IAM.
- **Deploy nhầm site:** luôn dùng `hosting:admin` và kiểm tra `.firebaserc`.
- **CSP trắng màn hình:** xem browser console; không xóa bừa CSP, đối chiếu đúng
  origin Firebase/Google hoặc renderer đang bị chặn.

## 17. Rollback

- Hosting: rollback release trong Firebase Console hoặc deploy artifact đã xác minh.
- Functions: deploy lại commit trước.
- Remote Config: dùng version history/rollback.
- Rules: deploy lại `storage.rules` và `firestore.rules` từ commit trước.
- Role: dùng script/backend tin cậy để bỏ claim và revoke refresh token.

Mọi thay đổi production nên được review, audit và có kế hoạch rollback.
