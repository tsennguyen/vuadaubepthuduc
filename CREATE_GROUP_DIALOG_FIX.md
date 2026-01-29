# Create Group Dialog Fix

## Vấn đề đã fix
Khi nhấn "Tạo nhóm" sau đó nhấn "Hủy", vẫn hiển thị thông báo lỗi "Tên nhóm không được để trống".

## Nguyên nhân
Logic xử lý không phân biệt được giữa:
- User nhấn **"Hủy"** (dialog return `null`)
- User nhấn **"Tạo"** với tên trống (dialog return empty string)

Code cũ:
```dart
if (result == null || result.trim().isEmpty) {
  messenger.showSnackBar(...); // Hiển thị lỗi
  return null;
}
```

→ Khi user nhấn "Hủy", `result` là `null` → Hiển thị lỗi (KHÔNG MONG MUỐN)

## Giải pháp

### 1. Tách logic kiểm tra null và empty
```dart
// If user canceled (null), return without error message
if (result == null) {
  return null;
}

// If user submitted but name is empty, show error
if (result.trim().isEmpty) {
  if (!context.mounted) return null;
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Tên nhóm không được để trống'),
      backgroundColor: theme.colorScheme.error,
      ...
    ),
  );
  return null;
}
```

✅ Kết quả:
- Nhấn "Hủy" → Đóng dialog, không lỗi
- Nhấn "Tạo" với tên trống → Hiển thị lỗi

### 2. Cải thiện UX với StatefulBuilder
Thêm validation realtime để:
- **Vô hiệu hóa nút "Tạo"** khi tên trống
- **Thay đổi màu nút** dựa theo trạng thái

```dart
builder: (dialogContext) => StatefulBuilder(
  builder: (context, setState) {
    final hasText = controller.text.trim().isNotEmpty;
    
    return Dialog(
      child: // ... TextField with onChanged
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}), // Update UI
          ...
        ),
        
        // ... Create button
        ElevatedButton(
          onPressed: hasText ? () { ... } : null, // Disable khi trống
          child: Text(
            'Tạo',
            style: TextStyle(
              color: hasText 
                ? Colors.white 
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
    );
  },
)
```

## UX Improvements

### Trước khi fix:
- ❌ Nhấn "Hủy" → Hiển thị "Tên nhóm không được để trống"
- ❌ Nút "Tạo" luôn sáng, ngay cả khi tên trống
- ❌ User có thể nhấn "Tạo" với tên trống

### Sau khi fix:
- ✅ Nhấn "Hủy" → Đóng dialog mượt mà, không lỗi
- ✅ Nút "Tạo" disabled (màu xám) khi tên trống
- ✅ Nút "Tạo" enabled (gradient) khi đã nhập tên
- ✅ Visual feedback ngay khi gõ

## Code Changes

### File: `create_chat_controller.dart`

#### 1. Dialog với StatefulBuilder
```diff
builder: (dialogContext) => 
+  StatefulBuilder(
+    builder: (context, setState) {
+      final hasText = controller.text.trim().isNotEmpty;
      
-      Dialog(...)
+      return Dialog(...);
+    },
+  )
```

#### 2. TextField với onChanged
```diff
TextField(
  controller: controller,
+ onChanged: (_) => setState(() {}),
  ...
)
```

#### 3. Dynamic button state
```diff
Container(
  decoration: BoxDecoration(
-   gradient: LinearGradient(...),
+   gradient: hasText ? LinearGradient(...) : null,
+   color: hasText ? null : theme.colorScheme.surfaceContainerHighest,
    ...
  ),
  child: ElevatedButton(
-   onPressed: () { ... },
+   onPressed: hasText ? () { ... } : null,
    child: Text(
      'Tạo',
      style: TextStyle(
-       color: Colors.white,
+       color: hasText ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    ),
  ),
)
```

#### 4. Separate null and empty checks
```diff
controller.dispose();
-if (result == null || result.trim().isEmpty) {
+
+// If user canceled (null), return without error message
+if (result == null) {
+  return null;
+}
+
+// If user submitted but name is empty, show error
+if (result.trim().isEmpty) {
  if (!context.mounted) return null;
  messenger.showSnackBar(...);
  return null;
}
```

## Testing

### Test Case 1: Cancel ✅
1. Nhấn "Tạo nhóm"
2. Không nhập tên (để trống hoặc nhập rồi xóa)
3. Nhấn **"Hủy"**
4. ✅ Dialog đóng
5. ✅ **KHÔNG** hiển thị thông báo lỗi

### Test Case 2: Empty Submit (Not Possible Anymore) ✅
1. Nhấn "Tạo nhóm"
2. Không nhập tên
3. ✅ Nút "Tạo" bị **disabled** (màu xám)
4. ✅ Không thể nhấn được

### Test Case 3: Valid Name ✅
1. Nhấn "Tạo nhóm"
2. Nhập "Nhóm test"
3. ✅ Nút "Tạo" **enabled** (gradient màu)
4. Nhấn "Tạo"
5. ✅ Tiếp tục chọn thành viên
6. ✅ Tạo nhóm thành công

### Test Case 4: Type and Delete ✅
1. Nhấn "Tạo nhóm"
2. Nhập "abc"
3. ✅ Nút "Tạo" enabled
4. Xóa hết
5. ✅ Nút "Tạo" tự động disabled
6. Nhập lại
7. ✅ Nút "Tạo" tự động enabled lại

## Related Validations

Dialog này đã có các validations khác:
- ✅ Chỉ cho bạn bè tham gia nhóm
- ✅ Cần ít nhất 2 thành viên
- ✅ Kiểm tra user không bị ban

→ Giờ thêm validation cho tên nhóm với UX tốt hơn!

---

## Fix #2: Member Selection Dialog

### Vấn đề tương tự
Sau khi nhập tên nhóm, khi chọn thành viên:
- Nhấn "Hủy" → Vẫn hiển thị "Hãy chọn thành viên"

### Nguyên nhân
`UserPickerDialog.pickMulti()` return `[]` (empty list) cả khi:
- User cancel
- User submit nhưng không chọn ai

Code trong dialog:
```dart
static Future<List<AppUserSummary>> pickMulti(...) async {
  final result = await showDialog<List<AppUserSummary>>(...);
  return result ?? <AppUserSummary>[]; // null → []
}
```

### Giải pháp
Giả định: **Nếu picked.isEmpty, nghĩa là user đã cancel**

```dart
final picked = await UserPickerDialog.pickMulti(...);
if (!context.mounted) return null;

// If user didn't pick anyone, assume they canceled
// (Dialog requires at least one selection to submit)
if (picked.isEmpty) {
  return null; // Silent cancel, no error message
}
```

✅ Kết quả:
- Hủy chọn thành viên → Đóng mượt, không lỗi
- Các validation khác vẫn hoạt động bình thường

---

## Complete Flow Testing

### Scenario 1: Happy Path ✅
1. Nhấn "Tạo nhóm"
2. Nhập "Nhóm ABC" → Nhấn "Tạo"
3. Chọn 2 bạn bè → Nhấn "OK"
4. ✅ Tạo nhóm thành công

### Scenario 2: Cancel at Name ✅
1. Nhấn "Tạo nhóm"
2. Nhấn "Hủy" (hoặc để trống và hủy)
3. ✅ Đóng, không lỗi

### Scenario 3: Cancel at Members ✅
1. Nhấn "Tạo nhóm"
2. Nhập "Nhóm ABC" → Nhấn "Tạo"
3. Nhấn "Hủy" trong dialog chọn thành viên
4. ✅ Đóng, không lỗi "Hãy chọn thành viên"

### Scenario 4: Validation - Non-friend ✅
1. Nhấn "Tạo nhóm"
2. Nhập tên → Nhấn "Tạo"
3. Chọn người không phải bạn bè
4. ✅ Hiển thị "Chỉ có thể thêm bạn bè vào nhóm"

---

## Summary

✅ **Tên nhóm:**
- Hủy → Không lỗi
- Submit trống → Không thể (nút disabled)

✅ **Chọn thành viên:**
- Hủy → Không lỗi
- Chọn người không phải bạn bè → Hiển thị lỗi đúng

