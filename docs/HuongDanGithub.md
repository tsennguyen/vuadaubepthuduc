# Huong dan GitHub

- Branching: main, develop, feat/<scope>, fix/<scope>. Mo PR vao develop tru khi release.
- Template PR: `.github/pull_request_template.md` (check analyze/emulator/screenshots/no-secrets).
- Issue templates: `.github/ISSUE_TEMPLATE/bug_report.yml`, `feature_request.yml`.
- Actions:
  - flutter-analyze.yml: format + flutter analyze.
  - deploy-web.yml: build web, hosting preview cho PR, deploy live khi merge main.
- Secrets: khong commit .env/google-services.json/facebook token/GEMINI_API_KEY; dung GitHub Secrets cho CI khi can.
- Quy tac review: it nhat 1 reviewer, giai thich thay doi, link task, dinh kem anh/video.
