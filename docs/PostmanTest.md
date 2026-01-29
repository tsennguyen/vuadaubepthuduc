# Postman / tai khoan test

- Base URL emulator: `http://localhost:5001/vuadaubep-<mssv>/us-central1`.
- Vi du request callable (POST):
  ```
  POST /suggestSearch
  {
    "data": { "q": "bun bo", "tokens": ["bun","bo"], "type": "recipe" }
  }
  ```
- Lay ID token:
  - Dang nhap qua app web emulator, copy token tu DevTools -> Application -> Local Storage.
  - Hoac dung `firebase auth:sign-in-with-email` de nhan idToken.
- Bien moi truong Postman:
  - `projectId`, `base`, `idToken`.
  - Header: `Authorization: Bearer {{idToken}}`, `Content-Type: application/json`.
- Khong luu token/secret that trong bo suu tap.
