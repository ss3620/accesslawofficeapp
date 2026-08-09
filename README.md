# Access Law Firm — client app

Flutter app (iOS + Android) for the firm's paying immigration clients:
activation-code sign-in, a shared chat with the attorney and receptionist, a
video lobby with a reception → attorney handoff, and appointment requests.

## Running it

```bash
cd apps/mobile
flutter pub get
flutter run
```

The app runs immediately with an **in-memory demo backend** — no Firebase
project needed. Follow [`docs/FIREBASE_SETUP.md`](../../docs/FIREBASE_SETUP.md)
to switch it to Firestore; the swap is automatic once real keys exist in
`lib/services/firebase_options.dart`.

### Demo walkthrough

| Step | How |
|---|---|
| Client sign-in | Any name + email, activation code `ALF-DEMO` |
| Staff sign-in | "Firm staff sign in" → `reception@accesslawfirm.com` / `reception123` |
| Attorney | `attorney@accesslawfirm.com` / `attorney123` |
| Admin | `admin@accesslawfirm.com` / `admin123` |

Demo data lives in memory, so a client and a staff member must be used in the
same app session to see each other.

## What is in the app

| Area | Screens |
|---|---|
| Client | Activation, home, chat, video lobby, appointment request, emergency alert |
| Staff | Sign-in, client list with lobby controls, per-client chat, codes and settings |

## Structure

```
lib/
  models/client_models.dart      # Client, message, lobby, appointment types
  services/app_backend.dart      # Backend interface
  services/local_backend.dart    # In-memory demo backend
  services/firebase_backend.dart # Firestore + Firebase Auth
  services/push_service.dart     # FCM token registration
  state/app_state.dart           # Session and data access
  screens/                       # Client and staff screens
  widgets/chat_view.dart         # Shared group-chat surface
```

Swapping backends happens in [`lib/main.dart`](lib/main.dart); every screen talks
to `AppBackend`, never to Firestore directly.

## Checks

```bash
flutter analyze
flutter test
```

## Not included by design

Payments, document uploads (both stay in Docketwise), embedded Zoom video (the
app opens the Zoom app), the public non-client lobby, and location tracking.
