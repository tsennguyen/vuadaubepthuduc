# 🌐 LOCALIZATION CHECKLIST - VUA ĐẦU BẾP THỦ ĐỨC

## 📋 TIẾN ĐỘ TỔNG QUAN

| Màn hình | Trạng thái | Số text hardcode | Ghi chú |
|----------|-----------|------------------|---------|
| ✅ Profile Page | **HOÀN THÀNH** | 21 → 0 | Đã sửa xong 100% |
| ⏳ Feed Page | Chưa kiểm tra | ? | Cần kiểm tra |
| ⏳ Recipe Page | Chưa kiểm tra | ? | Cần kiểm tra |
| ⏳ Planner Page | Chưa kiểm tra | ? | Cần kiểm tra |
| ⏳ Shopping List | Chưa kiểm tra | ? | Cần kiểm tra |
| ⏳ Chat Page | Chưa kiểm tra | ? | Cần kiểm tra |
| ⏳ Friends Page | Chưa kiểm tra | ? | Cần kiểm tra |
| ✅ Create Post | **HOÀN THÀNH** | 13 → 0 | Đã sửa + fix GlobalKey |
| ✅ Create Recipe | **HOÀN THÀNH** | 38 → 0 | Đã sửa + fix GlobalKey |
| ⏳ Post Detail | Chưa kiểm tra | ? | Cần kiểm tra |
| ⏳ Recipe Detail | Chưa kiểm tra | ? | Cần kiểm tra |

---

## ✅ 1. PROFILE PAGE - HOÀN THÀNH

### **File đã sửa:**
- ✅ `lib/app/l10n.dart` - Thêm 21 keys
- ✅ `lib/features/profile/presentation/profile_page.dart` - Thay 21 chỗ hardcode

### **Chi tiết:**
- ✅ Profile header (stats, buttons)
- ✅ Posts tab (title, empty state, loading, error)
- ✅ Recipes tab (title, empty state, loading, error)
- ✅ Saved tab (title, empty state, loading, error)
- ✅ Admin button
- ✅ Edit button

### **Kết quả:**
- 🎯 100% text UI đã localize
- 🎯 User-generated content KHÔNG bị dịch
- 🎯 Đổi ngôn ngữ NGAY, không reload
- 🎯 KHÔNG mất trạng thái

**📄 Tài liệu:** `LOCALIZATION_FIX_PROFILE.md`

---

## ⏳ 2. FEED PAGE - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Filter buttons (Latest, Hot, Following)
- [ ] Empty state
- [ ] Loading state
- [ ] Error messages
- [ ] Post cards
- [ ] Create post button

### **File cần xem:**
- `lib/features/feed/presentation/feed_page.dart`
- `lib/features/feed/widgets/post_card.dart`

---

## ⏳ 3. RECIPE PAGE - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Recipe list
- [ ] Filter/Sort options
- [ ] Empty state
- [ ] Loading state
- [ ] Error messages
- [ ] Recipe cards

### **File cần xem:**
- `lib/features/recipes/presentation/recipes_page.dart`
- `lib/features/recipes/widgets/recipe_card.dart`

---

## ⏳ 4. PLANNER PAGE - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Week navigation (Next Week, Prev Week, This Week)
- [ ] Meal types (Breakfast, Lunch, Dinner, Snack)
- [ ] Add Meal button
- [ ] AI Plan button
- [ ] Generate Shopping List
- [ ] Empty state
- [ ] Date labels

### **File cần xem:**
- `lib/features/planner/presentation/planner_page.dart`

---

## ⏳ 5. SHOPPING LIST - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Title
- [ ] Filter buttons (All, Unchecked, Checked)
- [ ] Category labels
- [ ] Empty state
- [ ] Add item button

### **File cần xem:**
- `lib/features/shopping/presentation/shopping_list_page.dart`

---

## ⏳ 6. CHAT PAGE - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Chat list
- [ ] Empty state
- [ ] Message input placeholder
- [ ] Send button
- [ ] Timestamp format

### **File cần xem:**
- `lib/features/chat/presentation/chat_page.dart`
- `lib/features/chat/presentation/chat_list_page.dart`

---

## ⏳ 7. FRIENDS PAGE - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Friends list
- [ ] Friend requests
- [ ] Add friend button
- [ ] Accept/Reject buttons
- [ ] Empty state

### **File cần xem:**
- `lib/features/social/presentation/friends_page.dart`

---

## ⏳ 8. CREATE POST - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Title
- [ ] Caption placeholder
- [ ] Add photo button
- [ ] Tags input
- [ ] Submit button
- [ ] Cancel button

### **File cần xem:**
- `lib/features/feed/presentation/create_post_page.dart`

---

## ⏳ 9. CREATE RECIPE - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Title
- [ ] Recipe name placeholder
- [ ] Ingredients section
- [ ] Steps section
- [ ] Cook time
- [ ] Difficulty
- [ ] Submit button

### **File cần xem:**
- `lib/features/recipes/presentation/create_recipe_page.dart`

---

## ⏳ 10. POST DETAIL - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Comments section
- [ ] Like button
- [ ] Share button
- [ ] Comment input
- [ ] Empty comments state

### **File cần xem:**
- `lib/features/feed/presentation/post_detail_page.dart`

---

## ⏳ 11. RECIPE DETAIL - ĐANG CHỜ

### **Cần kiểm tra:**
- [ ] Ingredients list
- [ ] Steps list
- [ ] Cook time label
- [ ] Difficulty label
- [ ] Rating
- [ ] Comments

### **File cần xem:**
- `lib/features/recipes/presentation/recipe_detail_page.dart`

---

## 🎯 NGUYÊN TẮC LOCALIZATION

### ✅ **PHẢI LOCALIZE:**
- Label, button, title
- Empty state message
- Loading message
- Error message
- Placeholder text
- Tooltip
- Dialog title/content

### ❌ **KHÔNG LOCALIZE:**
- Tên người dùng (displayName)
- Tên món ăn (recipe title)
- Nội dung bài viết (post caption)
- Comment của người dùng
- Bio của người dùng

### 📝 **PATTERN SỬ DỤNG:**

#### 1. Simple text:
```dart
// l10n.dart
String get buttonName => isVi ? 'Tên tiếng Việt' : 'English name';

// UI
Text(s.buttonName)
```

#### 2. Text có biến:
```dart
// l10n.dart
String userName(String name) => isVi ? 'Bài viết của $name' : '$name\'s posts';

// UI
Text(s.userName(displayName))
```

#### 3. Widget cần reactive update:
```dart
Consumer(
  builder: (context, ref, _) {
    final s = S(ref.watch(localeProvider));
    return Text(s.buttonName);
  },
)
```

---

## 📊 THỐNG KÊ TỔNG QUAN

- **Tổng số màn hình:** 11
- **Đã hoàn thành:** 3 (27%)
- **Đang chờ:** 8 (73%)
- **Tổng text đã sửa:** 72 (21 + 13 + 38)
- **Localization keys đã thêm:** 72

---

## 🚀 BƯỚC TIẾP THEO

1. **Chọn màn hình tiếp theo** (đề xuất: Feed Page hoặc Recipe Page)
2. **Kiểm tra file** để tìm text hardcode
3. **Thêm keys vào l10n.dart**
4. **Thay thế hardcode bằng localization**
5. **Test đổi ngôn ngữ**
6. **Cập nhật checklist**

---

**Cập nhật lần cuối:** 2025-12-31 17:10
**Người thực hiện:** Senior Flutter Developer (AI Assistant)
