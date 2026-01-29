# Ghi chu Firebase Auth token

- Firebase phat hanh ID token (JWT) sau dang nhap; chua uid + custom claims (role).
- Custom claims duoc gan boi Cloud Function setRole; client doc bang `getIdTokenResult()` va refresh voi `getIdToken(true)` khi doi role.
- Callable/HTTPS Cloud Functions tu verify ID token qua Admin SDK; khong can JWT thu cong.
- Khong log hoac commit token; dung emulator cho thu nghiem hoac auth:sign-in-with-email CLI de lay token tam.
