import 'package:flutter/material.dart';

class S {
  final Locale locale;
  S(this.locale);

  static S of(BuildContext context) {
    // This is a simplified version since we are using Riverpod
    // In actual use, we'd watch the provider, but here's a helper
    // to keep strings organized.
    return S(Localizations.localeOf(context));
  }

  bool get isVi => locale.languageCode == 'vi';

  // Navigation
  String get feed => isVi ? 'Bảng tin' : 'Feed';
  String get recipes => isVi ? 'Công thức' : 'Recipes';
  String get reels => isVi ? 'Reels' : 'Reels';
  String get planner => isVi ? 'Kế hoạch' : 'Planner';
  String get chat => isVi ? 'Trò chuyện' : 'Chat';
  String get profile => isVi ? 'Hồ sơ' : 'Profile';
  String get admin => isVi ? 'Quản trị' : 'Admin';

  // Profile
  String get edit => isVi ? 'Chỉnh sửa' : 'Edit';
  String get friends => isVi ? 'Bạn bè' : 'Friends';
  String get logout => isVi ? 'Đăng xuất' : 'Log out';
  String get settings => isVi ? 'Cài đặt' : 'Settings';
  String get lightMode => isVi ? 'Chế độ sáng' : 'Light Mode';
  String get darkMode => isVi ? 'Chế độ tối' : 'Dark Mode';
  String get toggleDarkMode => isVi ? 'Bật/tắt Dark Mode' : 'Toggle Dark Mode';

  // Auth
  String get login => isVi ? 'Đăng nhập' : 'Login';
  String get register => isVi ? 'Đăng ký' : 'Register';
  String get email => isVi ? 'Email' : 'Email';
  String get password => isVi ? 'Mật khẩu' : 'Password';
  String get forgotPassword => isVi ? 'Quên mật khẩu?' : 'Forgot password?';
  String get loginWithGoogle => isVi ? 'Đăng nhập với Google' : 'Sign in with Google';
  String get dontHaveAccount => isVi ? 'Chưa có tài khoản?' : "Don't have an account?";
  String get signupNow => isVi ? 'Đăng ký ngay' : 'Sign up now';

  // Common
  String get cancel => isVi ? 'Hủy' : 'Cancel';
  String get save => isVi ? 'Lưu' : 'Save';
  String get delete => isVi ? 'Xóa' : 'Delete';
  String get search => isVi ? 'Tìm kiếm' : 'Search';
  String get loading => isVi ? 'Đang tải...' : 'Loading...';
  String get retry => isVi ? 'Thử lại' : 'Retry';
  String get error => isVi ? 'Lỗi' : 'Error';

  // Feed
  String get filterLatest => isVi ? 'Mới nhất' : 'Latest';
  String get filterHot => isVi ? 'Nổi bật' : 'Hot';
  String get filterFollowing => isVi ? 'Theo dõi' : 'Following';
  String get emptyFeedTitle => isVi ? 'Chưa có bài nào' : 'No posts yet';
  String get emptyFeedSubtitle => isVi ? 'Theo dõi đầu bếp hoặc đổi bộ lọc để thấy nội dung.' : 'Follow chefs or change filters to see content.';
  String get loadingMore => isVi ? 'Đang tải thêm...' : 'Loading more...';
  String get loadingFeed => isVi ? 'Đang tải bảng tin...' : 'Loading feed...';
  String get loadingRecipes => isVi ? 'Đang tải công thức...' : 'Loading recipes...';
  String get whatsOnYourMind => isVi ? 'Bạn đang nghĩ gì?' : "What's on your mind?";
  String get emptyRecipesTitle => isVi ? 'Chưa có công thức' : 'No recipes yet';
  String get emptyRecipesSubtitle => isVi ? 'Hãy thử tạo mới hoặc quay lại sau.' : 'Try creating a new one or check back later.';

  // Planner
  String get nextWeek => isVi ? 'Tuần sau' : 'Next Week';
  String get prevWeek => isVi ? 'Tuần trước' : 'Prev Week';
  String get thisWeek => isVi ? 'Tuần này' : 'This Week';
  String get addMeal => isVi ? 'Thêm món' : 'Add Meal';
  String get aiPlan => isVi ? 'AI Plan' : 'AI Plan';
  String get generateShoppingList => isVi ? 'Tạo danh sách mua sắm' : 'Generate Shopping List';
  String get mealBreakfast => isVi ? 'Bữa sáng' : 'Breakfast';
  String get mealLunch => isVi ? 'Bữa trưa' : 'Lunch';
  String get mealDinner => isVi ? 'Bữa tối' : 'Dinner';
  String get mealSnack => isVi ? 'Bữa phụ' : 'Snack';
  String get todayLabel => isVi ? 'HÔM NAY' : 'TODAY';

  // Categories
  String get catVeg => isVi ? 'Rau Củ' : 'Vegetables';
  String get catMeat => isVi ? 'Thịt' : 'Meat';
  String get catSeafood => isVi ? 'Hải Sản' : 'Seafood';
  String get catSpices => isVi ? 'Gia Vị' : 'Spices';
  String get catGrains => isVi ? 'Ngũ Cốc' : 'Grains';
  String get catDairy => isVi ? 'Sữa' : 'Dairy';
  String get catOther => isVi ? 'Khác' : 'Other';

  // Shopping
  String get shopTitle => isVi ? 'Danh Sách Mua Sắm' : 'Shopping List';
  String get filterAll => isVi ? 'Tất cả' : 'All';
  String get filterUnchecked => isVi ? 'Chưa mua' : 'Unchecked';
  String get filterChecked => isVi ? 'Đã mua' : 'Checked';
  String get emptyShopTitle => isVi ? 'Danh sách trống' : 'Empty List';
  String get emptyShopSubtitle => isVi ? 'Thêm nguyên liệu từ công thức hoặc kế hoạch để bắt đầu.' : 'Add ingredients from recipes or planner to start.';

  // Intro
  String get skip => isVi ? 'Bỏ qua' : 'Skip';
  String get start => isVi ? 'Bắt đầu' : 'Get Started';
  String get slide1Title => isVi ? 'Chào mừng đến với\nVua Đầu Bếp Thủ Đức' : 'Welcome to\nVua Dau Bep Thu Duc';
  String get slide1Desc => isVi ? 'Nơi chia sẻ và khám phá hàng ngàn công thức nấu ăn từ cộng đồng đam mê ẩm thực.' : 'Share and discover thousands of recipes from the food-loving community.';
  String get slide2Title => isVi ? 'Khám phá công thức\nvà tủ món yêu thích' : 'Explore recipes\nand favorites';
  String get slide2Desc => isVi ? 'Tìm kiếm, lưu và thử nghiệm các món ăn yêu thích từ đầu bếp khắp mọi nơi.' : 'Search, save and experiment with your favorite dishes from chefs everywhere.';
  String get slide3Title => isVi ? 'Nấu ăn dễ dàng\nvới hướng dẫn chi tiết' : 'Easy cooking\nwith detailed guides';
  String get slide3Desc => isVi ? 'Làm theo từng bước, danh sách nguyên liệu và thời gian nấu chuẩn xác.' : 'Follow step-by-step, with precise ingredient lists and cooking times.';
  String get slide4Title => isVi ? 'Chia sẻ đam mê\nvới cộng đồng' : 'Share passion\nwith community';
  String get slide4Desc => isVi ? 'Đăng tải món ngon của bạn, nhận thả tim, bình luận và kết nối với mọi người.' : 'Post your delicious dishes, get likes, comments and connect with everyone.';

  // Profile - Additional
  String get user => isVi ? 'Người dùng' : 'User';
  String get language => isVi ? 'Ngôn ngữ' : 'Language';
  String get logoutConfirmTitle => isVi ? 'Đăng xuất' : 'Log out';
  String get logoutConfirmMessage => isVi ? 'Bạn có chắc chắn muốn đăng xuất khỏi Vua Đầu Bếp Thủ Đức?' : 'Are you sure you want to log out of Vua Dau Bep Thu Duc?';
  String get logoutError => isVi ? 'Không thể đăng xuất' : 'Cannot log out';
  
  // Relationship Status
  String get friendsFollowing => isVi ? 'Bạn bè · Đang theo dõi' : 'Friends · Following';
  String get following => isVi ? 'Đang theo dõi' : 'Following';
  String get sentYouRequest => isVi ? 'Đã gửi lời mời đến bạn' : 'Sent you a request';
  String waitingFor(String name) => isVi ? 'Đang chờ $name phản hồi...' : 'Waiting for $name...';
  
  // Friend Actions
  String get accept => isVi ? 'Đồng ý' : 'Accept';
  String get reject => isVi ? 'Từ chối' : 'Reject';
  String get message => isVi ? 'Nhắn tin' : 'Message';
  String get requestNotFound => isVi ? 'Không tìm thấy yêu cầu' : 'Request not found';
  String get cannotAccept => isVi ? 'Không thể chấp nhận' : 'Cannot accept';
  String get cannotReject => isVi ? 'Không thể từ chối' : 'Cannot reject';
  
  // Chat
  String get needFriendToChat => isVi ? 'Bạn cần kết bạn trước khi nhắn tin.' : 'You need to be friends before messaging.';
  String sendFriendRequestToUnlock(String name) => isVi ? 'Gửi lời mời kết bạn để mở khóa nhắn tin với $name.' : 'Send a friend request to unlock messaging with $name.';
  String get close => isVi ? 'Đóng' : 'Close';
  String get sendFriendRequest => isVi ? 'Gửi lời mời kết bạn' : 'Send Friend Request';
  String get cannotCreateChat => isVi ? 'Không tạo được chat' : 'Cannot create chat';
  
  // Chat List
  String get messages => isVi ? 'Tin nhắn' : 'Messages';
  String get newMessage => isVi ? 'Tin nhắn mới' : 'New message';
  String get createGroup => isVi ? 'Tạo nhóm' : 'Create Group';
  String get noChatsYet => isVi ? 'Chưa có cuộc trò chuyện nào' : 'No conversations yet';
  String get startChatting => isVi ? 'Bắt đầu trao đổi với bạn bè ngay nào!' : 'Start chatting with friends now!';
  String get startConversation => isVi ? 'Bắt đầu cuộc trò chuyện' : 'Start conversation';
  String get today => isVi ? 'Hôm nay' : 'Today';
  String get yesterday => isVi ? 'Hôm qua' : 'Yesterday';
  
  // Chat Room
  String get youDeletedMessage => isVi ? 'Bạn đã gỡ tin nhắn này' : 'You deleted this message';
  String get messageDeleted => isVi ? 'Tin nhắn đã bị gỡ' : 'Message deleted';
  String seenBy(int count) => isVi ? 'Đã xem bởi $count' : 'Seen by $count';
  String get replying => isVi ? 'Đang trả lời...' : 'Replying...';
  String get loadingImage => isVi ? 'Đang tải hình ảnh...' : 'Loading image...';
  String get loadingVideo => isVi ? 'Đang tải video...' : 'Loading video...';
  String get active => isVi ? 'Đang hoạt động' : 'Active';
  String get chatLocked => isVi ? 'Đoạn chat đã bị khóa bởi quản trị viên do vi phạm tiêu chuẩn cộng đồng.' : 'Chat locked by admin for violating community standards.';
  String get replyingTo => isVi ? 'Đang trả lời' : 'Replying to';
  String get editing => isVi ? 'Đang chỉnh sửa' : 'Editing';
  String get edited => isVi ? '(Đã chỉnh sửa)' : '(Edited)';
  String get image => isVi ? 'Ảnh' : 'Image';
  String get voiceMessage => isVi ? 'Tin nhắn thoại' : 'Voice message';
  String get errorOccurred => isVi ? 'Đã xảy ra lỗi: ' : 'An error occurred: ';
  String get agree => isVi ? 'Đồng ý' : 'Agree';
  String get reportSent => isVi ? 'Đã gửi báo cáo' : 'Report sent';
  
  // Chat Info Panel
  String get unnamedGroup => isVi ? 'Nhóm không tên' : 'Unnamed group';
  String get conversation => isVi ? 'Đoạn chat' : 'Conversation';
  String get renameGroup => isVi ? 'Đổi tên nhóm' : 'Rename group';
  String get setAsAdmin => isVi ? 'Đặt làm quản trị' : 'Set as admin';
  String addedMembers(int count) => isVi ? 'Đã thêm $count thành viên vào nhóm' : 'Added $count members to group';
  String pinnedMessages(int count) => isVi ? 'Tin nhắn đã ghim ($count)' : 'Pinned messages ($count)';
  
  // Report Dialog
  String get attachEvidence => isVi ? 'Đính kèm bằng chứng (Tùy chọn)' : 'Attach evidence (Optional)';
  String messagesCount(int count) => isVi ? 'Tin nhắn ($count/10)' : 'Messages ($count/10)';
  String imagesCount(int count) => isVi ? 'Ảnh ($count/5)' : 'Images ($count/5)';
  
  // User Picker
  String selectedUsers(int count) => isVi ? 'Đã chọn $count người' : '$count selected';
  
  // Edit Profile
  String get editProfile => isVi ? 'Chỉnh sửa hồ sơ' : 'Edit Profile';
  String get displayName => isVi ? 'Tên hiển thị' : 'Display Name';
  String get bio => isVi ? 'Giới thiệu' : 'Bio';
  String get avatarUrl => isVi ? 'Ảnh đại diện (URL)' : 'Avatar (URL)';
  String get avatar => isVi ? 'Ảnh đại diện' : 'Avatar';
  String get choosePhoto => isVi ? 'Chọn ảnh' : 'Choose Photo';
  String get fromCamera => isVi ? 'Chụp ảnh' : 'Take Photo';
  String get fromGallery => isVi ? 'Từ thư viện' : 'From Gallery';
  String get uploadingImage => isVi ? 'Đang tải ảnh lên...' : 'Uploading image...';
  String get nameRequired => isVi ? 'Tên không được để trống' : 'Name is required';
  
  // Delete Confirmations
  String get deletePost => isVi ? 'Xóa bài viết' : 'Delete Post';
  String get deletePostConfirm => isVi ? 'Bạn có chắc chắn muốn xóa bài viết này không?' : 'Are you sure you want to delete this post?';
  String get postDeleted => isVi ? 'Đã xóa bài viết' : 'Post deleted';
  String get cannotDelete => isVi ? 'Không thể xóa' : 'Cannot delete';
  
  String get deleteRecipe => isVi ? 'Xóa công thức' : 'Delete Recipe';
  String get deleteRecipeConfirm => isVi ? 'Bạn có chắc chắn muốn xóa công thức này không?' : 'Are you sure you want to delete this recipe?';
  String get recipeDeleted => isVi ? 'Đã xóa công thức' : 'Recipe deleted';
  
  // Profile Stats & Info
  String get needLoginToViewProfile => isVi ? 'Bạn cần đăng nhập để xem hồ sơ của mình.' : 'You need to login to view your profile.';
  String get cannotLoadStats => isVi ? 'Không tải được thống kê' : 'Cannot load stats';
  String get posts => isVi ? 'Bài viết' : 'Posts';
  String get saved => isVi ? 'Đã lưu' : 'Saved';
  
  // Profile Header
  String cannotLoadStatsError(String error) => isVi ? 'Không tải được thống kê: $error' : 'Cannot load stats: $error';
  
  // Profile Tabs
  String userPosts(String name) => isVi ? 'Bài viết của $name' : '$name\'s posts';
  String userRecipes(String name) => isVi ? 'Công thức của $name' : '$name\'s recipes';
  String get savedItems => isVi ? 'Mục đã lưu' : 'Saved Items';
  
  // Empty States
  String get noPostsYet => isVi ? 'Chưa có dữ liệu bài viết để hiển thị.' : 'No posts to display yet.';
  String get noPostsDesc => isVi ? 'Viết bài mới để chia sẻ cùng mọi người.' : 'Create a new post to share with everyone.';
  String get noRecipesYet => isVi ? 'Chưa có dữ liệu công thức để hiển thị.' : 'No recipes to display yet.';
  String get noRecipesDesc => isVi ? 'Chia sẻ món ngon đầu tiên của bạn.' : 'Share your first delicious dish.';
  String get noSavedYet => isVi ? 'Bạn chưa lưu công thức/bài viết nào.' : 'You haven\'t saved any recipes or posts yet.';
  String get noSavedDesc => isVi ? 'Lưu lại món hay bài viết để xem sau.' : 'Save recipes or posts to view later.';
  
  // Loading States
  String get loadingPosts => isVi ? 'Đang tải bài viết...' : 'Loading posts...';
  String get loadingSaved => isVi ? 'Đang tải mục đã lưu...' : 'Loading saved items...';
  
  // Error States
  String cannotLoadPosts(String error) => isVi ? 'Không tải được bài viết: $error' : 'Cannot load posts: $error';
  String cannotLoadRecipes(String error) => isVi ? 'Không tải được công thức: $error' : 'Cannot load recipes: $error';
  String cannotLoadSaved(String error) => isVi ? 'Không tải được mục đã lưu: $error' : 'Cannot load saved items: $error';
  
  // Saved Items
  String savedPost(String id) => isVi ? 'Bài viết $id' : 'Post $id';
  String get savedPostTodo => isVi ? 'TODO: hiển thị chi tiết bài viết đã lưu' : 'TODO: display saved post details';
  String itemNotFound(String id) => isVi ? 'Không tìm thấy mục $id' : 'Item $id not found';
  
  // Create Post
  String get createPost => isVi ? 'Tạo Bài Viết' : 'Create Post';
  String get postTitle => isVi ? 'Tiêu đề' : 'Title';
  String get postTitleHint => isVi ? 'Nhập tiêu đề bài viết...' : 'Enter post title...';
  String get postContent => isVi ? 'Nội dung' : 'Content';
  String get postContentHint => isVi ? 'Chia sẻ suy nghĩ của bạn...' : 'Share your thoughts...';
  String get tags => isVi ? 'Tags' : 'Tags';
  String get tagsHint => isVi ? 'Phân tách bởi dấu phẩy (VD: ẩm thực, công thức, món ngon)' : 'Separate by comma (e.g., food, recipe, delicious)';
  String get selectImages => isVi ? 'Chọn ảnh' : 'Select Images';
  String get publishPost => isVi ? 'Đăng Bài' : 'Publish';
  String get pleaseLogin => isVi ? 'Vui lòng đăng nhập' : 'Please login';
  String get postPublishedSuccess => isVi ? ' Đã đăng bài viết thành công' : ' Post published successfully';
  String errorMessage(String error) => isVi ? 'Lỗi: $error' : 'Error: $error';
  String imagesSelected(int count) => isVi ? 'Ảnh đã chọn ($count)' : 'Images selected ($count)';
  
  // Create Recipe
  String get createRecipe => isVi ? 'Đăng Công Thức' : 'Create Recipe';
  String get editRecipe => isVi ? 'Chỉnh Sửa Công Thức' : 'Edit Recipe';
  String get recipeName => isVi ? 'Tên món' : 'Recipe Name';
  String get recipeNameHint => isVi ? 'Nhập tên món ăn...' : 'Enter recipe name...';
  String get description => isVi ? 'Mô tả' : 'Description';
  String get descriptionHint => isVi ? 'Mô tả về món ăn...' : 'Describe the dish...';
  String get cookTime => isVi ? 'Thời gian nấu' : 'Cook Time';
  String get minutes => isVi ? 'phút' : 'm';
  String get hours => isVi ? 'giờ' : 'h';
  String get days => isVi ? 'ngày' : 'd';
  String get justNow => isVi ? 'Vừa xong' : 'Just now';
  String get minutesAgo => isVi ? 'phút trước' : 'm ago';
  String get hoursAgo => isVi ? 'giờ trước' : 'h ago';
  String get daysAgo => isVi ? 'ngày trước' : 'd ago';
  String get difficulty => isVi ? 'Độ khó' : 'Difficulty';
  String get difficultyEasy => isVi ? 'Dễ' : 'Easy';
  String get difficultyMedium => isVi ? 'Trung bình' : 'Medium';
  String get difficultyHard => isVi ? 'Khó' : 'Hard';
  String get ingredients => isVi ? 'Nguyên Liệu' : 'Ingredients';
  String get steps => isVi ? 'Các Bước Thực Hiện' : 'Steps';
  String get recipeTagsHint => isVi ? 'Phân tách bằng dấu phẩy (VD: món Việt, dễ làm, ít béo)' : 'Separate by comma (e.g., Vietnamese, easy, low-fat)';
  String get coverImage => isVi ? 'Ảnh bìa' : 'Cover Image';
  String get selectCoverImage => isVi ? 'Chọn ảnh bìa' : 'Select cover image';
  String get nutritionInfo => isVi ? 'Giá trị dinh dưỡng' : 'Nutrition Info';
  String get nutritionPerServing => isVi ? 'Giá trị trên mỗi khẩu phần' : 'Per serving';
  String get aiEstimate => isVi ? 'AI Ước lượng' : 'AI Estimate';
  String get estimating => isVi ? 'Đang tính...' : 'Estimating...';
  String get nutritionHint => isVi ? 'Điền nguyên liệu rồi nhấn "AI Ước lượng" để tự động tính dinh dưỡng' : 'Fill ingredients then tap "AI Estimate" to auto-calculate nutrition';
  String get publishRecipe => isVi ? 'Đăng Công Thức' : 'Publish Recipe';
  String get saveChanges => isVi ? 'Lưu Thay Đổi' : 'Save Changes';
  String get recipePublishedSuccess => isVi ? '✅ Đã đăng công thức thành công' : '✅ Recipe published successfully';
  String get recipeSavedSuccess => isVi ? '✅ Đã lưu công thức' : '✅ Recipe saved';
  String get recipeNotFound => isVi ? 'Không tìm thấy công thức' : 'Recipe not found';
  String get hideRecipe => isVi ? 'Ẩn' : 'Hide';
  String get deleteForever => isVi ? 'Xoá vĩnh viễn' : 'Delete Forever';
  String get recipeHidden => isVi ? 'Đã ẩn công thức' : 'Recipe hidden';
  String get recipeDeletedForever => isVi ? 'Đã xoá vĩnh viễn' : 'Deleted forever';
  String get add => isVi ? 'Thêm' : 'Add';
  String get remove => isVi ? 'Xóa' : 'Remove';
  String get enterContent => isVi ? 'Nhập nội dung...' : 'Enter content...';

  // Nutrition Advisor
  String get nutritionAdvisor => isVi ? 'Trợ lý Dinh dưỡng' : 'Nutrition Advisor';
  String get nutritionAdviceTitle => isVi ? 'Tư vấn Dinh dưỡng' : 'Nutrition Advice';
  String get selectGoal => isVi ? 'Chọn mục tiêu của bạn' : 'Select your goal';
  String get goalWeightLoss => isVi ? 'Giảm cân' : 'Weight Loss';
  String get goalMuscleGain => isVi ? 'Tăng cơ' : 'Muscle Gain';
  String get goalHealthy => isVi ? 'Ăn lành mạnh' : 'Healthy Eating';
  String get goalSnack => isVi ? 'Bữa nhẹ' : 'Snack';
  String get analyzeByGoal => isVi ? 'Phân tích theo mục tiêu' : 'Analyze by Goal';
  String get thinking => isVi ? 'Đang phân tích...' : 'Analyzing...';
  String get nutritionSummary => isVi ? 'Tổng quan' : 'Summary';
  String get nutritionAssessment => isVi ? 'Đánh giá' : 'Assessment';
  String get nutritionSuggestions => isVi ? 'Gợi ý điều chỉnh' : 'Suggestions';

  // Flippable Card
  String get didYouKnow => isVi ? 'Có thể bạn chưa biết' : 'Did you know?';
  String get seeFunFact => isVi ? 'Xem sự thật thú vị' : 'See fun fact';
  String get tapToFlipBack => isVi ? 'Chạm để lật lại' : 'Tap to flip back';
  String get aiSearchingFact => isVi ? 'AI đang tìm câu chuyện...' : 'AI is finding a story...';
  String get noFactFound => isVi ? 'Ồ, mình chưa tìm thấy thông tin thú vị nào về món này rồi! Thử lại sau nhé.' : 'Oh, I haven\'t found any interesting facts about this dish yet! Try again later.';

  String translateDifficulty(String? difficulty) {
    if (difficulty == null) return isVi ? 'Chưa rõ' : 'Unknown';
    final d = difficulty.toLowerCase();
    if (d == 'easy' || d == 'dễ' || d == 'de') return difficultyEasy;
    if (d == 'medium' || d == 'trung bình' || d == 'trung binh') {
      return difficultyMedium;
    }
    if (d == 'hard' || d == 'khó' || d == 'kho') return difficultyHard;
    return difficulty;
  }

  // Notifications
  String get noNotifications => isVi ? 'Không có thông báo' : 'No notifications';
  String get markAllRead => isVi ? 'Đánh dấu tất cả đã đọc' : 'Mark all as read';
  String get markAllReadSuccess => isVi ? '✓ Đã đánh dấu tất cả là đã đọc' : '✓ All marked as read';
  String get notificationLikedPost => isVi ? 'đã thích bài viết của bạn' : 'liked your post';
  String get notificationLikedRecipe => isVi ? 'đã thích công thức của bạn' : 'liked your recipe';
  String get notificationCommented => isVi ? 'đã bình luận:' : 'commented:';
  String get notificationReplied => isVi ? 'đã trả lời bình luận:' : 'replied to comment:';
  String get notificationSharedPost => isVi ? 'đã chia sẻ bài viết của bạn' : 'shared your post';
  String get notificationSharedRecipe => isVi ? 'đã chia sẻ công thức của bạn' : 'shared your recipe';
  String get notificationSavedRecipe => isVi ? 'đã lưu công thức của bạn' : 'saved your recipe';
  String get notificationRatedPost => isVi ? 'đã đánh giá bài viết của bạn' : 'rated your post';
  String get notificationRatedRecipe => isVi ? 'đã đánh giá công thức của bạn' : 'rated your recipe';
  String get notificationFollowed => isVi ? 'đã theo dõi bạn' : 'followed you';
  String get notificationFriendRequest => isVi ? 'đã gửi lời mời kết bạn' : 'sent you a friend request';
  String get notificationFriendAccepted => isVi ? 'đã chấp nhận lời mời kết bạn của bạn' : 'accepted your friend request';
  String get notifications => isVi ? 'Thông báo' : 'Notifications';
}
