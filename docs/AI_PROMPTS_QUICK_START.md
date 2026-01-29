# Hướng dẫn sử dụng trang AI Prompts Management

## Tổng quan
Trang **AI Prompts** cho phép Admin quản lý tập trung tất cả các prompts AI trong hệ thống.

## Các tính năng chính

### 1. **Khởi tạo configs mặc định**
- Nếu chưa có config nào trong Firestore, bạn sẽ thấy màn hình rỗng
- Click nút **"Khởi tạo configs mặc định"** để tạo 8 configs:
  - search
  - recipe_suggest
  - meal_plan
  - nutrition  
  - chef_chat
  - chat_moderation
  - report_moderation
  - recipe_enrich

### 2. **Tìm kiếm configs**
- Dùng thanh search để tìm theo:
  - Tên config
  - ID config
  - Mô tả

### 3. **Xem thống kê**
- Stats bar hiển thị:
  - **Tổng**: Số lượng configs
  - **Đang bật**: Số configs đang enabled
  - **Đang tắt**: Số configs đang disabled

### 4. **Bật/Tắt tính năng**
- Toggle switch bên cạnh mỗi config
- Khi tắt, Firebase Functions sẽ từ chối requests cho feature đó

### 5. **Chỉnh sửa config**
Click **"Chỉnh sửa"** để mở dialog:

#### Các trường có thể sửa:
- **Model**: Tên model OpenAI (gpt-4o-mini, gpt-4-turbo, etc.)
- **Temperature**: 0.0 - 1.0
  - Thấp (0.1-0.3): Structured output, ít sáng tạo
  - Cao (0.6-0.9): Creative content
- **Max Output Tokens**: Giới hạn độ dài response
- **System Prompt**: Hướng dẫn cho AI (role, rules)
- **User Prompt Template**: Template cho user input
  - Dùng `{{variable}}` cho placeholders
  - VD: `{{ingredients}}`, `{{query}}`, `{{contextJson}}`

### 6. **Reset về mặc định**
- Click **"Reset về mặc định"**
- Xóa config khỏi Firestore
- Functions sẽ tự động dùng hardcoded defaults

### 7. **Bulk Actions**
Click icon menu (⋮) ở góc trên bên phải:
- **Làm mới**: Reload danh sách
- **Khởi tạo defaults**: Seed lại tất cả configs

## Template Variables chi tiết

### search
```
{{query}} - User search query
```

### recipe_suggest
```
{{ingredients}} - Danh sách nguyên liệu
{{servingsLine}} - Số khẩu phần (optional)
{{maxTimeLine}} - Thời gian tối đa (optional)
{{allergiesLine}} - Danh sách dị ứng (optional)
{{dietTagsLine}} - Chế độ ăn (optional)
```

### meal_plan
```
{{weekDates}} - Danh sách 7 ngày
{{contextJson}} - JSON {dietGoal, macroTarget, mealsPerDay, favoriteIngredients, allergies}
```

### nutrition
```
{{ingredientsJson}} - JSON danh sách nguyên liệu + servings
```

### chef_chat
```
{{history}} - Lịch sử conversation
{{message}} - Tin nhắn mới từ user
```

### chat_moderation
```
{{chatId}} - ID của chat
{{messageId}} - ID của message
{{senderId}} - ID người gửi
{{messageType}} - Loại tin nhắn
{{sentAt}} - Thời gian gửi
{{attachmentUrl}} - URL attachment (nếu có)
{{messageText}} - Nội dung tin nhắn
```

### report_moderation
```
{{targetType}} - Loại bị báo cáo (post/recipe/comment/chat)
{{targetId}} - ID của target
{{reasonLine}} - Lý do báo cáo (optional)
{{noteLine}} - Ghi chú (optional)
{{content}} - Nội dung bị báo cáo
```

### recipe_enrich
```
{{inputJson}} - JSON {title, description, rawIngredients}
```

## Tips

### Khi nào nên chỉnh sửa prompts?

1. **Output không đúng format**
   - Thêm ví dụ cụ thể vào System Prompt
   - Nhấn mạnh JSON schema

2. **AI không hiểu tiếng Việt tốt**
   - Thêm "Dùng tiếng Việt" vào System Prompt
   - Dùng "không dấu" cho keywords

3. **Response quá dài/ngắn**
   - Điều chỉnh maxOutputTokens
   - Thêm constraints vào prompt

4. **Cần thay đổi tone/style**
   - Sửa System Prompt
   - VD: "Trả lời ngắn gọn, thân thiện"

### Test prompts

1. Sửa prompt trong Admin UI
2. Đợi 60s (cache expiry)
3. Test trong app
4. Nếu không tốt, rollback hoặc tiếp tục sửa

### Backup & Restore

- Firestore console → Export `aiConfigs` collection
- Để restore: Import lại vào Firestore

## Lưu ý quan trọng

⚠️ **Cẩn thận khi sửa System Prompt**
- Thay đổi có thể ảnh hưởng toàn bộ AI behavior
- Luôn test kỹ trước khi deploy production

⚠️ **Model costs**
- gpt-4-turbo đắt hơn gpt-4o-mini rất nhiều
- Chỉ dùng turbo khi thực sự cần

⚠️ **Cache 60s**
- Functions cache configs 1 phút
- Đợi ít nhất 60s để thấy changes

⚠️ **Firestore limits**
- Collection aiConfigs cần Firestore security rules
- Chỉ admin mới được read/write
