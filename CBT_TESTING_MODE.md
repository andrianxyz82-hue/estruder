# CBT Testing Mode - Switch Instructions

## 🧪 CURRENT MODE: WEB PREVIEW (Chrome Testing)

Aplikasi saat ini menggunakan **Web Preview Mode** untuk testing di Chrome.
Mode ini menonaktifkan semua fitur keamanan native Android.

---

## ✅ Untuk Testing di Chrome (MODE SAAT INI):

File yang digunakan: `cbt_exam_screen_web_preview.dart`

**Fitur yang DINONAKTIFKAN:**
- ❌ Lock Mode (Screen Pinning)
- ❌ FLAG_SECURE (Anti-screenshot)
- ❌ Overlay Detection
- ❌ Security Check Loop
- ❌ Permission Dialog

**Yang TETAP BERFUNGSI:**
- ✅ WebView loading
- ✅ URL dari teacher
- ✅ Timeout detection (30s)
- ✅ Error handling
- ✅ Exit button

---

## 🔒 Untuk Kembalikan ke Production Mode (Android):

### Langkah 1: Edit `lib/core/app_router.dart`

**GANTI baris 41:**

```dart
// DARI (Web Preview):
builder: (context, state) => const CbtExamScreenWebPreview(),

// KE (Production):
builder: (context, state) => const CbtExamScreen(),
```

### Langkah 2: Hapus import web preview (OPTIONAL)

**HAPUS baris 20:**
```dart
import 'package:safe_exam_app/features/exam/cbt_exam_screen_web_preview.dart';
```

### Langkah 3: Test di Android Device/Emulator

```bash
flutter run -d <device-id>
```

---

## 📝 File Locations:

- **Web Preview**: `lib/features/exam/cbt_exam_screen_web_preview.dart`
- **Production**: `lib/features/exam/cbt_exam_screen.dart`
- **Router**: `lib/core/app_router.dart`

---

## ⚠️ PENTING:

- **JANGAN** push ke production dengan Web Preview mode aktif!
- **SELALU** test di Android device sebelum deploy
- Web Preview hanya untuk validasi WebView functionality
