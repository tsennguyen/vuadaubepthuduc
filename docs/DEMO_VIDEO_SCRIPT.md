# KỊCH BẢN QUAY VIDEO DEMO - VUA ĐẦU BẾP THỦ ĐỨC (FULL VERSION)

**Đề tài**: Vua Đầu Bếp - Ứng dụng mạng xã hội chia sẻ công thức nấu ăn  
**Giảng viên hướng dẫn**: ThS. Nguyễn Quang Huy  
**Nhóm thực hiện**: Nguyễn Việt Thành, Phan Trúc Giang, Đỗ Thanh Hiệp, Ngô Minh Hùng  
**Thời lượng dự kiến**: 20-25 phút  
**Ngày cập nhật**: 2026-01-04

---

## 🎬 PHẦN MỞ ĐẦU (30 giây)

### [CẢNH 0] - GIỚI THIỆU DỰ ÁN
**⏱️ Thời lượng**: 30 giây

**📝 Text chuyển cảnh**:
```
BÁO CÁO ĐỒ ÁN
LẬP TRÌNH THIẾT BỊ DI ĐỘNG

VUA ĐẦU BẾP THỦ ĐỨC
Ứng dụng Mạng xã hội Chia sẻ Công thức Nấu ăn

GVHD: ThS. Nguyễn Quang Huy
Nhóm SV: Nguyễn Việt Thành, Phan Trúc Giang,
         Đỗ Thanh Hiệp, Ngô Minh Hùng
```

**🎤 Lời thoại**:
> "Kính chào Thầy. Nhóm em xin trình bày đồ án Lập trình Thiết bị Di động với đề tài: Vua Đầu Bếp Thủ Đức - Ứng dụng mạng xã hội chia sẻ công thức nấu ăn, được xây dựng trên Flutter và Firebase, tích hợp AI thông minh."

---

## 📱 PHẦN DEMO CHÍNH

---

### [CẢNH 1] - INTRO & ĐĂNG NHẬP
**⏱️ Thời lượng**: 1 phút 30 giây

**📝 Text chuyển cảnh**:
```
CẢNH 1: GIỚI THIỆU VÀ XÁC THỰC
3.4.1 Module Giới thiệu (Intro/Trailer) và Xác thực
```

**🎤 Lời thoại**:
> "Khi khởi động ứng dụng, người dùng được chào đón bằng 4 slide giới thiệu tính năng cốt lõi: Khám phá công thức, Nấu ăn dễ dàng, và Chia sẻ đam mê với cộng đồng. Sau đó có thể đăng nhập qua Email hoặc Google Sign-in."

**📱 Hành động**:

**[Hình 3.6a-3.6d] - Intro Slides** (30s):
1. Launch app → Splash screen (2s)
2. **Slide 1**: "Chào mừng đến với Vua Đầu Bếp Thủ Đức"
   - Hiển thị illustration lớn, title, subtitle
   - Nút "Bỏ qua" góc trên, nút "Tiếp theo" phía dưới
3. **Swipe left** → **Slide 2**: "Khám phá công thức"
   - Icon tìm kiếm, hình minh họa recipes
   - Dots indicator (slide 2/4)
4. **Swipe left** → **Slide 3**: "Nấu ăn dễ dàng"
   - Icon chef hat, hình minh họa steps
5. **Swipe left** → **Slide 4**: "Chia sẻ đam mê"
   - Icon community, hình minh họa social/reels
   - Nút "Bắt đầu" thay vì "Tiếp theo"
6. **Tap "Bắt đầu"**

**[Hình 3.7a] - Login Screen** (30s):
7. Màn hình Login hiển thị:
   - Logo app ở top
   - Email field (filled: user@test.com)
   - Password field (filled: ••••••)
   - Button "Đăng nhập"
   - Divider "Hoặc"
   - Button "Đăng nhập với Google" (icon Google)
   - Link "Quên mật khẩu?" và "Đăng ký ngay"
8. **Tap "Đăng nhập"** → Loading (1s) → Success

**[Optional - Hình 3.7b, 3.7c]** (nếu có thời gian):
- Tap "Đăng ký ngay" → **Register screen** → Back
- Tap "Quên mật khẩu?" → **Forgot password screen** → Back

**⏰ Checkpoint**: Đã đăng nhập thành công, redirect to Feed

---

### [CẢNH 2] - BẢNG TIN VÀ MẠNG XÃ HỘI
**⏱️ Thời lượng**: 2 phút 30 giây

**📝 Text chuyển cảnh**:
```
CẢNH 2: BẢNG TIN VÀ MẠNG XÃ HỘI
3.4.2 Hệ thống Feed và Tương tác Xã hội
```

**🎤 Lời thoại**:
> "Bảng tin chính hiển thị các bài đăng từ cộng đồng theo thời gian thực. Người dùng chọn bộ lọc Mới nhất, Nổi bật hoặc Đang theo dõi. Hệ thống hỗ trợ 4 loại biểu cảm: Like, Love, Haha, Wow, cùng bình luận có đính kèm ảnh và emoji."

**📱 Hành động**:

**[Hình 3.8a] - Feed Page** (30s):
1. App redirect to `/feed` (tab Feed active)
2. Feed hiển thị:
   - Filter chips ở top: **"Mới nhất"** (selected), "Nổi bật", "Theo dõi"
   - Post cards stream (3-5 posts visible)
3. **Tap chip "Nổi bất"** → Feed refresh với hot posts
4. **Tap chip "Mới nhất"** → Back to latest
5. **Scroll down** xem thêm posts (smooth scroll)

**[Hình 3.8b] - Create Post** (30s):
6. **Tap FAB button "+"** (floating action button)
7. Modal hiển thị: "Tạo bài viết" / "Tạo công thức" / "Tạo Reel"
8. **Chọn "Tạo bài viết"** → Navigate to `/create-post`
9. Create Post screen:
   - Title input (type: "Món ăn Tết ngon!")
   - Content textarea (type: "Chia sẻ món bánh chưng truyền thống...")
   - Button "Thêm ảnh" → Pick image from gallery
   - Tags input (type: "Tết, Truyền thống")
   - Button "Đăng bài"
10. **Tap "Đăng bài"** → Loading → Success → Back to Feed
11. Post vừa tạo xuất hiện ở top Feed

**[Hình 3.9a-3.9d] - Post Detail & Comments** (1m30s):
12. **Tap vào 1 post** có nhiều reactions/comments
13. **Post Detail page** hiển thị:
    - Author avatar + name + timestamp
    - Post image (full width)
    - Title (lớn, bold)
    - Content
    - **4 Reaction buttons**: Like ❤️, Love 😍, Haha 😂, Wow 😮 (với counts)
    - Comments count
    - Share button
14. **Demo 4 Reactions**:
    - **Tap icon reaction** (currently none) → Popup 4 icons
    - **Chọn Love 😍** → Count tăng, icon turn red
15. **Scroll down** to Comments section
16. **[Hình 3.9b]** - Xem threaded comments:
    - Comment 1 (top-level)
    - → Reply 1.1 (indent)
    - → Reply 1.2 (indent)
    - Comment 2 (top-level)
17. **[Hình 3.9c]** - Demo comment với ảnh + emoji:
    - Tap **"Viết bình luận..."** input box
    - Keyboard hiện ra
    - Type: "Món này nhìn ngon quá"
    - **Tap icon emoji** 😊 → Emoji picker hiển thị
    - **Chọn emoji 😍** → Insert vào text: "Món này nhìn ngon quá 😍"
    - **Tap icon camera** 📷 → Pick image modal
    - **Chọn ảnh từ gallery** → Thumbnail preview hiển thị
    - **Tap "Gửi"** → Comment được post
18. **[Hình 3.9d]** - Comment card vừa gửi hiển thị:
    - Avatar + Name + timestamp
    - Text: "Món này nhìn ngon quá 😍"
    - Ảnh đính kèm (ClipRRect, maxHeight 250px)
    - Like button, Reply button
19. **Back** to Feed

**⏰ Checkpoint**: Đã tạo post, reaction, comment với ảnh + emoji

---

### [CẢNH 3] - TÌM KIẾM THÔNG MINH
**⏱️ Thời lượng**: 2 phút

**📝 Text chuyển cảnh**:
```
CẢNH 3: TÌM KIẾM THÔNG MINH
Tìm kiếm Recipes, Posts, Users và AI Suggestions
```

**🎤 Lời thoại**:
> "Module tìm kiếm hỗ trợ tìm kiếm công thức, bài viết. Đặc biệt, khi không tìm thấy kết quả, AI sẽ gợi ý các món ăn phù hợp. Người dùng có thể tìm tác giả bằng cú pháp @ theo sau tên."

**📱 Hành động**:

**[Hình mới - Search Page]** (2m):
1. **Tap icon Search** 🔍 (bottom nav hoặc top bar)
2. Navigate to `/search`
3. **Search screen** hiển thị:
   - Search bar lớn ở top (placeholder: "Tìm kiếm món ăn, bài viết...")
   - Trending keywords chips: "Phở", "Bánh mì", "Tết"...
   - Filter tabs: **All** / Recipes / Posts / Users

**Demo 1: Search Recipes** (30s):
4. **Tap vào search bar** → Keyboard
5. **Type**: "Phở bò"
6. Suggestions dropdown (nếu có): "Phở bò Hà Nội", "Phở bò Nam Định"...
7. **Tap "Search"** or **Enter**
8. Results page:
   - Tab **"Recipes"** active
   - Grid recipes matching "Phở bò" (2-3 results)
   - Recipe cards: ảnh, title, rating

**Demo 2: AI Suggestions khi không có kết quả** (40s):
9. **Clear search** → Type: "xyzabc123" (query không có kết quả)
10. **Tap Search**
11. "Không tìm thấy kết quả" message
12. **AI Suggestions section** hiển thị:
    - Title: "Có thể bạn quan tâm - Gợi ý từ AI"
    - 3 AI suggested recipe cards (từ trending hoặc AI generate)
    - Button "Xem thêm gợi ý AI"

**Demo 3: Search Author với @** (30s):
13. **Clear search** → Type: "@Nguyễn"
14. Dropdown suggestions: "@Nguyễn Văn A", "@Nguyễn Thị B"...
15. **Chọn "@Nguyễn Văn A"**
16. Results:
    - Tab **"Users"** active
    - User card: avatar, name "Nguyễn Văn A", bio, Follow button
17. **Tap vào user** → Navigate to Profile page (xem nhanh) → Back

**Demo 4: Filter tabs** (20s):
18. **Tap tab "Posts"** → Chỉ hiển thị posts matching query
19. **Tap tab "All"** → Mixed results (Recipes + Posts + Users)

20. **Back** to Home

**⏰ Checkpoint**: Đã search recipes, users, xem AI suggestions

---

### [CẢNH 4] - REELS (VIDEO NGẮN)
**⏱️ Thời lượng**: 1 phút 30 giây

**📝 Text chuyển cảnh**:
```
CẢNH 4: VIDEO NGẮN REELS
3.4.3 Module Reels - Video dọc hiện đại ⭐ MỚI
```

**🎤 Lời thoại**:
> "Tính năng Reels cho phép chia sẻ video nấu ăn dọc, tương tự TikTok. Video tự động phát full screen, hỗ trợ swipe để xem tiếp, và tương tác realtime với sidebar likes, comments, shares."

**📱 Hành động**:

**[Hình 3.10a] - Reels Feed** (1m):
1. **Tap tab "Reels"** (bottom nav)
2. Navigate to `/reels`
3. **Video 1 tự động phát** full screen:
   - Video player với nội dung nấu ăn (vertical)
   - **Sidebar bên phải**:
     - Author avatar (tap để xem profile)
     - ❤️ Like button + count (ví dụ: 124)
     - 💬 Comment button + count (ví dụ: 15)
     - ↗️ Share button
     - 🔖 Save button
   - **Bottom overlay**:
     - Author name: "@chef_pro"
     - Title: "Cách làm Phở Bò chuẩn Hà Nội"
     - Description: "Bí quyết nước dùng trong veo..."
     - Hashtags: #Phở #HàNội #Tutorial
4. **Demo tương tác**:
   - **Tap Like ❤️** → Heart animation, count tăng 124→125
   - **Tap Comment 💬** → Bottom sheet comments modal hiển thị
     - List comments
     - Input box "Viết bình luận..."
     - **Tap outside** để đóng
5. **Swipe up** (vertical swipe) → Video 2 phát
6. **Swipe up** → Video 3 phát
7. (Optional) **Swipe down** → Back to previous video

**[Hình 3.10b] - Create Reel** (30s):
8. **Tap FAB "+"** → Chọn **"Tạo Reel"**
9. Navigate to `/create-reel`
10. **Create Reel screen**:
    - Button **"Chọn video"** → Pick from gallery
    - Video preview player
    - **Thumbnail** auto-generated (hoặc pick custom)
    - Title input: "Cách làm Bánh Mì"
    - Description textarea
    - Tags input: "BánhMì, Tutorial"
    - Button **"Đăng Reel"**
11. (Không cần đăng thật) → **Back** to Reels feed

**⏰ Checkpoint**: Đã xem reels, tương tác, demo create form

---

### [CẢNH 5] - CÔNG THỨC & FLIPPABLE CARD
**⏱️ Thời lượng**: 3 phút

**📝 Text chuyển cảnh**:
```
CẢNH 5: CÔNG THỨC VÀ THẺ LẬT 3D
3.4.4 Chi tiết Công thức với AI nhận diện nguồn gốc ⭐⭐
```

**🎤 Lời thoại**:
> "Module công thức cung cấp hướng dẫn chi tiết từng bước có ảnh minh họa. Đặc biệt, widget FlippableDishCard với hiệu ứng lật 3D cho phép tap vào ảnh món ăn để xem câu chuyện nguồn gốc do AI cung cấp."

**📱 Hành động**:

**[Hình 3.11a] - Recipes Grid** (20s):
1. **Tap tab "Recipes"** (bottom nav)
2. Navigate to `/recipes`
3. **Recipes Grid** hiển thị:
   - Layout 2-3 columns responsive
   - Recipe cards:
     - Cover image
     - Title: "Phở Bò Hà Nội"
     - Rating: ⭐⭐⭐⭐⭐ 4.8
     - Cook time: 120 phút
     - Difficulty badge: "Trung bình"
4. **Scroll** xem 2-3 hàng recipes

**[Hình 3.12a-3.12b] - FlippableDishCard 3D** (1m):
5. **Tap vào recipe "Phở Bò Hà Nội"**
6. Navigate to `/recipe/{id}`
7. **Recipe Detail page** hiển thị:
   - **[Hình 3.12a] - FRONT side**:
     - **FlippableDishCard** ở top (Hero animation)
     - Ảnh món Phở Bò full width, high quality
     - **Hint text overlay**: "Chạm để xem nguồn gốc" ✨
     - Icon sparkle animation
8. **🌟 TAP VÀO ẢNH** → **Animation lật 3D** (600ms)
9. **[Hình 3.12b] - BACK side**:
   - Gradient background (primary → secondary colors)
   - Icon ✨ ở top
   - Title: **"Có thể bạn chưa biết"**
   - **AI fun fact text** (2-3 câu):
     > "Phở Bò xuất hiện từ đầu thế kỷ 20 tại Hà Nội, được ảnh hưởng từ món pot-au-feu của Pháp. Tên gọi 'Phở' có thể xuất phát từ âm 'feu' trong tiếng Pháp."
   - Hint: "Chạm để lật lại" (bottom)
10. **Pause 5s** để đọc text
11. **TAP LẠI** → Lật về mặt trước (animation 600ms)

**[Hình 3.13a-3.13c] - Recipe Detail đầy đủ** (1m20s):
12. **Scroll down** từ FlippableDishCard
13. **[Hình 3.13a] - Thông tin tổng quan**:
    - Recipe title: "Phở Bò Hà Nội"
    - Author info: Avatar + Name + "Theo dõi" button
    - Row icons:
      - 🍳 Difficulty: Trung bình
      - ⏱️ Cook time: 120 phút
      - 👥 Servings: 4 người
    - Tags: #Phở #HàNội #TraditionalFood
14. **Scroll down** → **Nguyên liệu** section:
    - Title "Nguyên liệu"
    - Checkbox list:
      - ☐ 500g thịt bò
      - ☐ 300g bánh phở
      - ☐ Hành tây, gừng...
    - Button "Thêm vào Shopping List"
15. **[Hình 3.13b] - Các bước thực hiện**:
    - Title "Các bước"
    - Step 1:
      - Number badge "1"
      - Text: "Rửa sạch xương, chần qua nước sôi..."
      - Ảnh minh họa step 1
    - Step 2, 3, 4... (scroll qua nhanh)
16. **[Hình 3.13c] - Giá trị dinh dưỡng**:
    - Title "Dinh dưỡng" với badge **"AI Estimate"**
    - 🔥 Calories: 450 kcal
    - 🥩 Protein: 25g
    - 🍚 Carbs: 55g
    - 🧈 Fat: 12g
17. **Scroll down** → Ratings & Comments section:
    - Average rating: ⭐⭐⭐⭐⭐ 4.8/5
    - Comments (tương tự Post comments)

**[Hình 3.13d-3.13e] - Create Recipe** (20s):
18. **Back** to Recipes grid
19. **Tap FAB "+"** → **"Tạo công thức"**
20. Navigate to `/create-recipe`
21. **[Hình 3.13d] - Create Recipe Form**:
    - Title input (type: "Bún Bò Huế")
    - Description textarea
    - **Upload cover image** button → Pick image
    - Difficulty dropdown: Dễ / Trung bình / Khó
    - Cook time input: 90 phút
    - Servings input: 4
    - Ingredients list (add/remove rows)
    - Steps list (add/remove steps với ảnh)
22. **Scroll to bottom** → **[Hình 3.13e] - AI Estimate Nutrition**:
    - Button **"AI Ước lượng dinh dưỡng"**
    - **Tap button** → Loading spinner (2s)
    - Results hiển thị:
      - Calories: ~500 kcal
      - Protein: 28g
      - Carbs: 60g
      - Fat: 15g
    - (Không cần save) → **Back**

**⏰ Checkpoint**: Đã demo FlippableDishCard 3D, xem recipe detail, AI nutrition

---

### [CẢNH 6] - CHEF AI & ĐA NGÔN NGỮ
**⏱️ Thời lượng**: 2 phút 30 giây

**📝 Text chuyển cảnh**:
```
CẢNH 6: TRỢ LÝ ẢO CHEF AI
3.4.5 Module Chef AI và Hệ thống đa ngôn ngữ ⭐
```

**🎤 Lời thoại**:
> "Chef AI là trợ lý ảo thông minh, tư vấn thay thế nguyên liệu, gợi ý món ăn từ tủ lạnh, phân tích dinh dưỡng. Ứng dụng hỗ trợ chuyển đổi tức thì giữa Tiếng Việt và English trong toàn bộ giao diện."

**📱 Hành động**:

**[Hình 3.14a-3.14c] - Chef AI Chat** (1m30s):
1. **Tap icon "AI Chef"** (từ menu hoặc bottom nav)
2. Navigate to `/ai-assistant`
3. **[Hình 3.14a] - AI Assistant Page**:
   - Header: "Chef AI Assistant" với icon robot 🤖
   - Chat interface:
     - Welcome message: "Xin chào! Tôi là Chef AI. Tôi có thể giúp gì cho bạn?"
     - Message bubbles (user right, AI left)
   - Input box + Send button
4. **[Hình 3.14b] - Demo hỏi thay thế nguyên liệu**:
   - **Type**: "Thay thế bơ bằng gì khi làm bánh?"
   - **Tap Send**
   - AI typing indicator (3 dots) (2s)
   - **AI Response**:
     > "Bạn có thể thay thế bơ bằng: 1) Dầu thực vật (canola, olive), 2) Sữa chua Hy Lạp, 3) Bơ đậu phộng, 4) Chuối nghiền (cho bánh ngọt)..."
5. **[Hình 3.14c] - Demo gợi ý món từ pantry**:
   - **Type**: "Tôi có trứng, cà chua, hành. Làm món gì?"
   - **Tap Send**
   - AI typing... (2s)
   - **AI Response**:
     > "Từ nguyên liệu có sẵn, bạn có thể làm:
     > 1. Trứng chiên cà chua - Đơn giản, 15 phút
     > 2. Cơm chiên trứng - Nhanh, 10 phút
     > 3. Trứng ốp la với hành... Bạn muốn công thức chi tiết món nào?"
6. (Optional) **Type**: "Món 1" → AI cung cấp recipe chi tiết

**[Hình 3.15a-3.15c] - Đa ngôn ngữ Vi/En** (1m):
7. **Back** to Home
8. **Tap tab "Profile"** → Own profile
9. **Tap icon Settings** ⚙️ (top right)
10. **[Hình 3.15a] - Settings Page**:
    - List options:
      - Account
      - Privacy
      - **→ Ngôn ngữ / Language** ← (tap this)
      - Notifications
      - About
11. **Language Settings** modal hiển thị:
    - Radio list:
      - ○ **🇻🇳 Tiếng Việt** (checked)
      - ○ 🇬🇧 English
12. **[Hình 3.15b] - Giao diện Tiếng Việt**:
    - Current UI: "Bảng tin", "Công thức", "Reels", "Bình luận", "Chia sẻ"...
    - (Capture screenshot để so sánh)
13. **Tap "🇬🇧 English"** → Confirm dialog → **OK**
14. **App tự động reload UI** (hoặc instant change)
15. **[Hình 3.15c] - Giao diện English**:
    - UI đã chuyển: "Feed", "Recipes", "Reels", "Comments", "Share"...
    - Bottom nav: Feed, Recipes, Reels, Chat, Profile
    - (Pause để thấy rõ sự khác biệt)
16. **Tap "🇻🇳 Tiếng Việt"** → Đổi lại về Vietnamese
17. **Back** to Home

**⏰ Checkpoint**: Đã chat với AI, đổi ngôn ngữ Vi/En thành công

---

### [CẢNH 7] - PLANNER & SHOPPING
**⏱️ Thời lượng**: 2 phút

**📝 Text chuyển cảnh**:
```
CẢNH 7: QUẢN LÝ BỮA ĂN
3.4.6 Module Quản lý: Planner, Shopping List và Macro Dashboard
```

**🎤 Lời thoại**:
> "Hệ thống Planner giúp lập thực đơn cho cả tuần. Từ đó, Shopping List tự động tổng hợp nguyên liệu cần mua. Macro Dashboard biểu thị trực quan các chỉ số dinh dưỡng qua biểu đồ."

**📱 Hành động**:

**[Hình 3.16a-3.16c] - Meal Planner** (1m):
1. **Tap tab "Planner"** (bottom nav hoặc menu)
2. Navigate to `/planner`
3. **[Hình 3.16a] - Planner Page**:
   - **Calendar 7 ngày**: Mon, Tue, Wed, Thu, Fri, Sat, Sun
   - **Tabs**: Breakfast / Lunch / Dinner / Snack (Lunch selected)
   - **Current week** hiển thị (ví dụ: Jan 1-7, 2026)
   - Cells:
     - Mon-Lunch: "Phở Bò" (recipe card với thumbnail)
     - Tue-Lunch: Empty (Add meal button)
     - Wed-Lunch: "Bún Bò Huế"
     - Thu-Lunch: Empty
     - ...
4. **Tap "Add meal" vào Tuesday-Lunch**
5. Modal **"Chọn món ăn"**:
   - Search bar
   - List recent recipes
6. **Chọn "Cơm Rang"** → Recipe added to Tue-Lunch cell
7. **[Hình 3.16b] - Navigation buttons**:
   - Top bar: **"< Prev Week"** | **"This Week"** | **"Next Week >"**
   - Button **"AI Plan"** (AI generate meal plan for week)
8. **Tap "AI Plan"** → Loading (2s) → Success toast "Đã tạo kế hoạch tuần!"
9. Calendar cells tự động fill với AI suggested meals
10. **[Hình 3.16c] - Generate Shopping List**:
    - Bottom button **"Tạo danh sách mua sắm"**
    - **Tap button** → Navigate to Shopping List

**[Hình 3.16f] - Shopping List** (1m):
11. Navigate to `/shopping` (hoặc auto from Planner)
12. **Shopping List Page**:
    - Title "Danh sách mua sắm"
    - **Filter chips**: **Tất cả** (selected) / Chưa mua / Đã mua
    - **Categorized list**:
      - **Rau củ**:
        - ☐ Hành tây (2 củ)
        - ☐ Cà chua (500g)
      - **Thịt**:
        - ☐ Thịt bò (1kg)
      - **Gia vị**:
        - ☐ Muối (1 gói)
        - ☐ Tiêu (1 hũ)
      - ...
13. **Demo tick items**:
    - **Tap checkbox "Hành tây"** → Checked ✓, text strikethrough
    - **Tap checkbox "Cà chua"** → Checked ✓
14. **Tap filter "Đã mua"** → Chỉ hiển thị items đã check
15. **Tap filter "Chưa mua"** → Chỉ hiển thị items chưa check
16. **Tap filter "Tất cả"** → Back to full list

**[Optional - Macro Dashboard nếu có thời gian]**:
17. **Tap icon "Macro Dashboard"** (menu)
18. Navigate to `/macro-dashboard`
19. **Dashboard hiển thị**:
    - Bar chart: Calories theo 7 ngày (Mon-Sun)
    - Line chart: Protein, Carbs, Fat trends
    - Pie chart: Breakdown hôm nay (Protein 25%, Carbs 55%, Fat 20%)
20. **Back**

**⏰ Checkpoint**: Đã add meal to planner, generate shopping list, tick items

---

### [CẢNH 8] - PROFILE & TABS
**⏱️ Thời lượng**: 2 phút

**📝 Text chuyển cảnh**:
```
CẢNH 8: HỒ SƠ CÁ NHÂN
3.4.7 Hồ sơ (Profile) và Quản lý nội dung
```

**🎤 Lời thoại**:
> "Profile cho phép quản lý thông tin cá nhân, bài đăng, công thức, và đặc biệt là tab Reels riêng. Người dùng có thể upload avatar từ camera hoặc thư viện."

**📱 Hành động**:

**[Hình 3.19a-3.19f] - Profile Page** (1m30s):
1. **Tap tab "Profile"** (bottom nav)
2. Navigate to `/profile` hoặc `/me`
3. **[Hình 3.19a] - Profile Header**:
   - **Avatar** lớn (circular, 120x120)
   - Display name: "Nguyễn Việt Thành"
   - Bio: "Food lover | Home chef 👨‍🍳"
   - **Stats row**:
     - 45 Posts
     - 28 Recipes
     - 12 Reels
   - **Button "Chỉnh sửa hồ sơ"**
4. **[Hình 3.19b] - Upload Avatar**:
   - **Tap icon camera** trên avatar (overlay)
   - **Bottom sheet** hiển thị:
     - 📷 Chụp ảnh
     - 🖼️ Từ thư viện
     - ❌ Hủy
   - **Chọn "Từ thư viện"** → Image picker
   - **Pick ảnh mới** → Preview dialog → **OK**
   - Avatar tự động update (upload to Firebase Storage)
5. **Tabs navigation**:
   - **Posts** | Recipes | Reels | Saved (Posts selected)
6. **[Hình 3.19c] - Tab Posts**:
   - Grid layout 3 columns
   - User's posts (thumbnails)
   - (Scroll xem 2-3 hàng)
7. **Tap tab "Recipes"**
8. **[Hình 3.19d] - Tab Recipes**:
   - Grid user's recipes
   - Recipe cards: image, title, rating
9. **Tap tab "Reels"** ⭐
10. **[Hình 3.19e] - Tab Reels**:
    - **Vertical grid** (1 column on mobile, 2-3 on web)
    - Reel thumbnails với:
      - Video thumbnail
      - Views count: 👁️ 1.2K
      - Duration: 0:45
11. **Tap tab "Saved"**
12. **[Hình 3.19f] - Tab Saved**:
    - Grid bookmarked recipes
    - Icon bookmark 🔖 trên mỗi card

**[Hình 3.19g-3.19k] - Notifications, Friends, Chat** (30s):
13. **Back** to Home
14. **[Hình 3.19g] - Tap icon Notifications** 🔔
15. Navigate to `/notifications`
16. **Notifications Page**:
    - List items:
      - "👤 @user_a đã theo dõi bạn" (5m ago)
      - "❤️ @user_b đã thích bài viết của bạn" (10m ago)
      - "💬 @user_c đã bình luận..." (1h ago)
      - "⭐ @user_d đã đánh giá công thức..." (2h ago)
    - Button top: **"Đánh dấu tất cả đã đọc"**
    - **Tap button** → All notifications marked read, badge = 0
17. **[Hình 3.19h] - Friends Page**:
    - Navigate to `/friends`
    - **Tabs**: Friends / Requests
    - **Friends tab**:
      - List friends (avatar, name, mutual count)
    - **Requests tab**:
      - Pending friend requests
      - "User X gửi lời mời" → **Accept** / **Reject** buttons
18. **[Hình 3.19i-3.19k] - Chat**:
    - Navigate to `/chat`
    - **Chat List**:
      - DM với "User A" (last message: "Ok bạn!")
      - Group "Nhóm Nấu Ăn" (last message: "Ai có công thức...")
    - **Tap vào DM** → Chat Room
    - **1-1 Chat**:
      - Messages stream (user right, peer left)
      - Input box "Nhắn tin..."
      - (Optional) **Type "Chào!"** → **Send**
    - **Back** → **Tap vào Group**
    - **Group Chat**:
      - Multiple members messages
      - Group name + member avatars top
    - **Back** to Home

**⏰ Checkpoint**: Đã xem profile tabs, upload avatar, notifications, chat

---

### [CẢNH 9] - ADMIN PANEL
**⏱️ Thời lượng**: 2 phút 30 giây

**📝 Text chuyển cảnh**:
```
CẢNH 9: QUẢN TRỊ HỆ THỐNG
3.5 Admin Panel - Quản lý nội dung và AI
```

**🎤 Lời thoại**:
> "Admin Panel cung cấp bảng điều khiển tập trung để quản lý người dùng, duyệt nội dung Reels, xử lý báo cáo, kiểm duyệt chat, và quan trọng nhất là hiệu chỉnh các prompt của Chef AI."

**📱 Hành động**:

**Lưu ý**: Cần đăng nhập tài khoản Admin:
0. **Đăng xuất** user hiện tại → **Login** với `admin@test.com`
1. App detect admin role → **Bottom nav chuyển sang Admin mode**
   - Icons thay đổi: Dashboard, Users, Content, Reports, Settings

**[Hình 3.20a] - Admin Dashboard** (20s):
2. **Tap tab "Admin"** (bottom nav)
3. Navigate to `/admin/overview`
4. **Admin Dashboard**:
   - **Stats cards** (4 cards):
     - 📊 Total Users: 1,234
     - 📝 Total Posts: 567
     - 🍳 Total Recipes: 345
     - 🎬 Total Reels: 89
   - **Charts**:
     - Line chart: New users by day (last 7 days)
     - Pie chart: Content distribution (Posts 40%, Recipes 35%, Reels 25%)
   - **Quick actions**: "Manage Users", "View Reports", "AI Prompts"

**[Hình 3.20b] - Admin Users** (20s):
5. **Tap "Users"** (sidebar hoặc bottom nav)
6. Navigate to `/admin/users`
7. **Admin Users Page**:
   - **Table** với columns:
     - Email | Name | Role | Status | Actions
   - Rows:
     - user1@test.com | Nguyễn A | client | active | [Ban] [Change Role▼]
     - user2@test.com | Trần B | client | banned | [Unban]
     - ...
   - **Demo**: Hover row → **Click dropdown "Change Role"**
   - Options: client / moderator / admin
   - (Không thực sự change) → Click outside to close

**[Hình 3.20c] - Admin Content** (30s):
8. **Tap "Content"** (sidebar hoặc nav)
9. Navigate to `/admin/content`
10. **Admin Content Page**:
    - **Tabs**: Posts / Recipes / **Reels** ⭐
    - **Tab Reels** active:
      - Table columns:
        - Thumbnail | Title | Author | Views | Hidden | Actions
      - Rows:
        - [thumb] "Làm Phở" | @chef_a | 1.2K | ❌ No | [Hide] [Delete]
        - [thumb] "Bánh Mì" | @chef_b | 850 | ✅ Yes | [Show] [Delete]
    - **Demo duyệt Reels**:
      - Row "Bánh Mì" có `hidden: true`
      - **Click "Show"** → Confirm dialog → **OK**
      - Status change: ✅ Yes → ❌ No
      - Reel được approve, hiển thị với users

**[Hình 3.20d] - Admin Reports** (20s):
11. **Tap "Reports"** (nav)
12. Navigate to `/admin/reports`
13. **Admin Reports Page**:
    - Table:
      - Reporter | Target | Reason | Status | AI Verdict | Actions
    - Rows:
      - @user_x | Post #123 | Spam | pending | 🤖 Low risk | [Resolve] [Dismiss]
      - @user_y | User @bad | Harassment | pending | 🚨 High risk | [Resolve] [Dismiss]
    - **Demo**: **Click "Resolve"** trên row 1 → Status: pending → resolved

**[Hình 3.20e] - Admin Chat Moderation** (15s):
14. **Tap "Chats"** (nav)
15. Navigate to `/admin/chats`
16. **Chat Moderation Page**:
    - List chat violations:
      - Chat ID | Violated by | Reason | Status | Actions
    - **Demo**: **Click "Lock Chat"** → Chat bị khóa, users không gửi tin nhắn được

**[Hình 3.20f-3.20g] - Admin AI Prompts** (30s):
17. **Tap "AI Prompts"** (nav) ⭐⭐
18. Navigate to `/admin/ai-prompts`
19. **Admin AI Prompts Page**:
    - **Table**:
      - Config Name | Model | Temperature | Status | Actions
    - Rows:
      - Chef AI Chat | gpt-4 | 0.7 | ✅ Enabled | [Edit]
      - Recipe Suggestions | gpt-3.5 | 0.8 | ✅ Enabled | [Edit]
      - Nutrition Analysis | gpt-4 | 0.5 | ❌ Disabled | [Edit]
20. **Click "Edit"** trên "Chef AI Chat"
21. **Edit AI Config Modal**:
    - Model dropdown: gpt-3.5 / **gpt-4** (selected) / gpt-4-turbo
    - Temperature slider: 0.7
    - **SystemPrompt** textarea:
      ```
      You are an expert Vietnamese chef assistant.
      Provide helpful cooking advice in Vietnamese.
      Be friendly, concise, and accurate.
      ```
    - UserPromptTemplate input
    - Enable/Disable toggle
    - **Save** button
22. **Demo**: Change temperature 0.7 → 0.8 → **Save** → Success toast

**[Hình 3.20h] - Admin Settings, Audit Logs** (15s):
23. **Tap "Settings"** → App-level settings page (Maintenance mode, Features...)
24. **Tap "Audit Logs"** → Read-only table (Timestamp, User, Action, Target)
25. **Back** to Dashboard

**⏰ Checkpoint**: Đã demo admin dashboard, manage users, duyệt reels, reports, AI prompts

---

## 🎯 PHẦN KẾT (30 giây)

### [CẢNH 10] - TỔNG KẾT
**⏱️ Thời lượng**: 30 giây

**📝 Text chuyển cảnh**:
```
TỔNG KẾT DỰ ÁN
VUA ĐẦU BẾP THỦ ĐỨC
```

**🎤 Lời thoại**:
> "Vua Đầu Bếp đã hiện thực thành công các tính năng cốt lõi: Mạng xã hội với Feed và Reels, Tìm kiếm thông minh với AI, Chef AI Assistant, FlippableDishCard độc đáo, Planner tự động hóa, Đa ngôn ngữ, và Admin Panel mạnh mẽ. Ứng dụng được xây dựng trên Flutter 3.x, Firebase, tích hợp OpenAI, đảm bảo hiệu năng và khả năng mở rộng. Em xin cảm ơn Thầy đã theo dõi!"

**📱 Hành động**: Hiển thị slide Công nghệ:
- Flutter 3.x + Riverpod 2.5
- Firebase (Auth, Firestore, Storage, Functions)
- OpenAI API / Gemini
- Video Player 2.9, Intl, Flutter Localizations
- Go Router 14.8, FL Chart

**📝 Text ending**:
```
CẢM ƠN QUÝ THẦY!

VUA ĐẦU BẾP THỦ ĐỨC
Nhóm: Nguyễn Việt Thành, Phan Trúc Giang,
      Đỗ Thanh Hiệp, Ngô Minh Hùng

GVHD: ThS. Nguyễn Quang Huy
Năm 2026
```

---

## 📊 TIMELINE TỔNG HỢP

| Cảnh | Module | Thời lượng | Tích lũy |
|------|--------|------------|----------|
| 0 | Giới thiệu | 30s | 0:30 |
| 1 | Intro & Auth | 1m30s | 2:00 |
| 2 | Feed & Social | 2m30s | 4:30 |
| 3 | Search + AI | 2m | 6:30 |
| 4 | Reels | 1m30s | 8:00 |
| 5 | Recipes & FlippableCard | 3m | 11:00 |
| 6 | Chef AI & i18n | 2m30s | 13:30 |
| 7 | Planner & Shopping | 2m | 15:30 |
| 8 | Profile & Tabs | 2m | 17:30 |
| 9 | Admin Panel | 2m30s | 20:00 |
| 10 | Tổng kết | 30s | 20:30 |

**Tổng thời lượng**: ~20-21 phút (Hoàn hảo!)

---

## ✅ CHECKLIST CHUẨN BỊ

### Trước khi quay:

**Kỹ thuật**:
- [ ] Screen recorder: OBS Studio (Windows) / QuickTime (Mac)
- [ ] Audio mic test (rõ ràng, không echo)
- [ ] Resolution: 1920x1080 (Full HD)
- [ ] FPS: 30fps
- [ ] Device: Pixel 5 API 33 emulator hoặc real device
- [ ] Internet: Ổn định cho Firebase realtime

**Dữ liệu mẫu** (QUAN TRỌNG!):
- [ ] **User account**: user@test.com / password123
- [ ] **Admin account**: admin@test.com / admin123
- [ ] Feed có 8-10 posts (với reactions, comments có ảnh)
- [ ] Recipes có 8-10 món (Phở Bò, Bún Bò Huế, Bánh Mì...) với ảnh đẹp
- [ ] Reels có 4-5 videos (vertical, cooking content)
- [ ] Chat có 2 DMs + 1 Group chat với messages
- [ ] Notifications có data (likes, comments, follows)
- [ ] Planner có meals assigned (Mon-Wed)
- [ ] Shopping list có items (categorized)
- [ ] Admin: Reports có 2-3 pending, Content có posts/recipes/reels
- [ ] Friends có 3-5 friends + 1 pending request

**Text slides**:
- [ ] Chuẩn bị 10 slides PowerPoint với text chuyển cảnh
- [ ] Font: Arial/Segoe UI, size 40pt+ (dễ đọc)
- [ ] Màu: Dark text on light bg hoặc ngược lại

**Script**:
- [ ] In file này ra giấy A4
- [ ] Highlight các phần quan trọng
- [ ] Luyện đọc 3 lần trước khi quay

---

## 💡 TIPS QUAN TRỌNG

### Do's ✅:
1. **Nói chậm, rõ ràng**: ~120 từ/phút
2. **Pause khi chuyển cảnh**: 1-2 giây
3. **Nhấn mạnh tính năng mới**: "⭐ MỚI", "Đặc biệt"
4. **Demo thực tế**: Tương tác thật, không fake data
5. **Keep time**: Mỗi cảnh đúng thời lượng, tổng ~20 phút
6. **Test trước**: Chạy through 1 lần để check flow

### Don'ts ❌:
1. ❌ Đọc nhanh → Thầy khó theo dõi
2. ❌ Skip steps → Mất tính liên tục
3. ❌ Để lỗi xảy ra → Test kỹ trước
4. ❌ Quá dài (>25m) hoặc quá ngắn (<15m)
5. ❌ Nhiễu audio → Tắt notifications, nhạc
6. ❌ Quay nhiều takes → Luyện trước để 1 take xong

---

## 🎯 GỢI Ý PHÂN CÔNG NHÓM

**Option 1: 1 người thuyết trình chính**
- **Nguyễn Việt Thành** (Nhóm trưởng):
  - Thuyết trình toàn bộ + điều khiển app
  - Backup: Giang/Hiệp chuẩn bị slides, data

**Option 2: Chia theo phần (4 người)**
- **Thành**: Cảnh 0-2 (Intro, Auth, Feed) - 4m30s
- **Giang**: Cảnh 3-5 (Search, Reels, Recipes) - 6m30s
- **Hiệp**: Cảnh 6-8 (AI, Planner, Profile) - 7m
- **Hùng**: Cảnh 9-10 (Admin, Tổng kết) - 3m

---

## 📋 DANH SÁCH HÌNH CẦN CHỤP (Tham khảo)

Tổng: **~45 hình** chính

- **3.6**: Intro slides (4 hình)
- **3.7**: Auth (3 hình)
- **3.8-3.9**: Feed & Social (8 hình)
- **Search**: (3 hình) - Bổ sung
- **3.10**: Reels (2 hình)
- **3.11-3.13**: Recipes & FlippableCard (8 hình)
- **3.14-3.15**: AI & i18n (6 hình)
- **3.16**: Planner & Shopping (4 hình)
- **3.19**: Profile (11 hình)
- **3.20**: Admin (8 hình)

---

**🎬 Chúc nhóm quay video thành công!**

*Lưu ý: Sau khi quay, có thể edit video (cắt ghép, add music intro/outro) bằng DaVinci Resolve, Adobe Premiere, hoặc CapCut để chuyên nghiệp hơn.*

---

**Ngày tạo**: 2026-01-04  
**Version**: 2.0 - Full Script với Search & All Features  
**Status**: ✅ Ready to Record
