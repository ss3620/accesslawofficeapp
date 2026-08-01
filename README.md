# Access Law Office — Flutter Mobile App

Hybrid mobile app (iOS + Android) for Access Law Office Virtual Lobby, built from [PRD-access-law-office-hybrid-app.md](../../PRD-access-law-office-hybrid-app.md).

## Stack

- **Flutter 3.41** / Dart 3.11
- **Provider** for app state
- **flutter_secure_storage** for visit token + staff session
- **url_launcher** for external Zoom join (Phase 1)
- **Mock API** locally (swap later for WordPress `/wp-json/alf/v1/`)

## Roles (one app binary)

| Role | Entry | Home |
|------|--------|------|
| Client | Join Virtual Lobby | Check-in wizard → waiting room |
| Receptionist | Staff sign in | Live queue |
| Admin | Staff sign in | Queue + Zoom settings + staff users |

## Demo credentials

- Admin: `admin` / `admin123`
- Receptionist: `receptionist` / `reception123`

## Run

```bash
cd apps/mobile
flutter pub get
flutter run
```

## MVP covered (P0 + P1)

- Launch gate: Join Lobby vs Staff sign in
- Client: name → phone → verify → matter → wait → Join Zoom
- Receptionist: queue Ready / Transfer / Complete / Dismiss + lobby toggle
- Admin: Zoom URLs / meeting numbers / passcodes, feature flags, create receptionist
- Session restore for active client visit and staff login

## Next phases

- Wire real WordPress REST API
- Push notifications (FCM / APNs)
- In-app messaging (Phase 2)
- Twilio Voice (Phase 3)
- Zoom Meeting SDK embed (Phase 1.5 / 4)
