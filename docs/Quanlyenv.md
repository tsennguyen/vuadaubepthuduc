# Quan ly .env

- Tao `.env` o root (khong commit):
  GEMINI_API_KEY=
  FACEBOOK_APP_ID=
  FACEBOOK_CLIENT_TOKEN=
- Chay app: `flutter run --dart-define-from-file=.env`
- Functions: doc GEMINI_API_KEY tu config/secrets; khong hardcode.
- Kiem tra .gitignore da chan .env, google-services.json, firebaseOptions.* neu co.
