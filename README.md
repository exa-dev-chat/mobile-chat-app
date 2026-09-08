# ChatApp Mobile (Flutter)

A modular, reactive, and responsive Flutter chat application built with **GetX**, **Dio**, **Logger**, **WebSocket**, **WebRTC**, and modern Flutter best practices.

---

## 🏗️ Architecture & Folder Structure

Proyek ini menggunakan arsitektur **Feature-Driven Modular** dipadukan dengan **Layered Separation of Concerns**:

```
mobile/
├── lib/
│   ├── main.dart                          # App bootstrap & global dependency injection
│   ├── core/                              # Shared foundation across all features
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # Timeouts, storage keys, breakpoints
│   │   │   └── api_endpoints.dart         # FastAPI backend endpoint paths
│   │   ├── network/
│   │   │   ├── api_client.dart            # Dio builder & HTTP helper methods
│   │   │   ├── api_exception.dart         # Standardized typed exceptions
│   │   │   └── interceptors/
│   │   │       ├── auth_interceptor.dart  # Bearer token injection & Mutex token refresh
│   │   │       ├── retry_interceptor.dart # Auto-retry on transient errors with backoff
│   │   │       ├── logging_interceptor.dart# Detailed network logging via LoggerService
│   │   │       └── error_interceptor.dart # Exception mapping & anti-spam error snackbar
│   │   ├── services/
│   │   │   ├── logger_service.dart        # Centralized rich logger
│   │   │   ├── snackbar_service.dart      # Centralized anti-spam snackbar
│   │   │   ├── storage_service.dart       # GetStorage wrapper for JWT & session
│   │   │   ├── websocket_service.dart     # Real-time WebSocket connection & signaling
│   │   │   ├── upload_service.dart        # Multipart file upload to MinIO (/api/upload)
│   │   │   └── voice_recorder_service.dart# Audio recording controller (AAC/M4A)
│   │   ├── theme/
│   │   │   ├── app_colors.dart            # Modern dark-mode palette & design tokens
│   │   │   └── app_theme.dart             # ThemeData with GoogleFonts (Outfit)
│   │   └── utils/
│   │       └── responsive.dart            # Responsive utilities & adaptive layout builder
│   ├── routes/
│   │   ├── app_routes.dart                # Route name definitions
│   │   └── app_pages.dart                 # GetPage mapping with bindings & transitions
│   └── modules/                           # Feature-driven modules
│       ├── splash/                        # Startup & session check
│       ├── auth/                          # Login, register, profile, and session
│       ├── call/                          # Audio & Video calling via WebRTC
│       │   ├── bindings/
│       │   ├── controllers/
│       │   ├── models/
│       │   └── views/
│       └── chat/                          # Chat rooms, messaging, responsive master-detail
│           ├── bindings/
│           ├── controllers/
│           ├── models/
│           └── views/
└── test/
    └── widget_test.dart                   # Unit & widget test suite
```

---

## 🌟 Key Features & Implementations

### 1. Centralized Anti-Spam Snackbar (`SnackbarService`)
- **Duplicate Message Suppression**: Menolak pesan identik dalam durasi 2.5 detik.
- **Single Active Snackbar**: Menutup snackbar lama sebelum menampilkan yang baru.
- **Context Guard**: Mencegah error saat overlay context belum siap.

### 2. Centralized Logger (`LoggerService`)
- Logger ANSI terformat rapi dengan emoji level (`d`, `i`, `w`, `e`).
- `LoggerService.network(...)` untuk pencatatan HTTP request, latency, headers, dan responses.
- Otomatis memfilter log sensitif di mode release.

### 3. Dio Interceptors Suite
- **`AuthInterceptor`**: Injeksi `Bearer <token>` + Mutex auto-refresh token saat 401.
- **`RetryInterceptor`**: Retry otomatis hingga 3x pada error transient dengan delay backoff.
- **`LoggingInterceptor`**: Pipe traffic HTTP ke `LoggerService`.
- **`ErrorInterceptor`**: Pemetaan error ke `ApiException` dan trigger snackbar error.

### 4. Real-Time WebSocket (`WebSocketService`)
- Terhubung ke `ws://<host>:8000/ws?token=<token>`.
- Heartbeat otomatis setiap 30s.
- Real-time live messaging (`new_message`).
- Typing indicator (`typing`).
- Presence tracking (`user_online` / `user_offline`).

### 5. WebRTC Audio & Video Calling (`modules/call/`)
- Audio & Video call P2P dengan signaling via WebSocket (`call:offer`, `call:answer`, `call:ice_candidate`, `call:reject`, `call:hangup`).
- Dialog panggilan masuk berdering (`IncomingCallDialog`).
- Layar panggilan aktif (`CallView`) dengan render video remote & local PIP, toggle mic, toggle camera, switch camera, speakerphone, dan hangup.

### 6. Voice Notes & Media Sharing
- Perekaman suara AAC via `record` package (`VoiceRecorderService`).
- Pemutar pesan suara di chat bubble (`VoiceNotePlayer`) via `audioplayers`.
- Pengunggahan foto dari Kamera/Galeri (`image_picker`) dan dokumen (`file_picker`) ke MinIO via `/api/upload`.

### 7. Responsive Master-Detail Design
- Breakpoints: Mobile `< 768px`, Tablet `768px - 1024px`, Desktop `> 1024px`.
- Tablet/Desktop: Tampilan 2 kolom berdampingan (Daftar chat + Detail obrolan aktif).
- Mobile: Tampilan obrolan satu kolom dengan navigasi layar penuh.

---

## 🚀 Cara Menjalankan

```bash
cd mobile
flutter pub get
flutter test
flutter run
```
