# Chef AI - Smart Cooking Assistant

## Tổng quan
Chef AI là trợ lý nấu ăn thông minh với khả năng:
- 🔍 **Tìm kiếm công thức** từ database Firestore realtime
- 💡 **Gợi ý món ăn** dựa trên nguyên liệu hoặc sở thích
- 👨‍🍳 **Hướng dẫn nấu ăn** chi tiết, mẹo và kỹ thuật
- 🥗 **Tư vấn dinh dưỡng** cơ bản
- 📅 **Lập kế hoạch bữa ăn** cân bằng

## Tính năng nổi bật

### 1. Recipe Database Integration
- Tự động tìm kiếm công thức từ Firestore khi user hỏi về món ăn
- Smart keyword detection (bún, phở, gà, chay, etc.)
- Relevance scoring algorithm để tìm công thức phù hợp nhất
- Hiển thị thông tin chi tiết: nguyên liệu, bước làm, thời gian, khẩu phần

### 2. Intelligent Conversation
- Nhớ lịch sử hội thoại (last 6 messages)
- Context-aware responses dựa trên cuộc trò chuyện trước
- Phản hồi bằng tiếng Việt, thân thiện và thực dụng

### 3. Practical Assistance
- Thay thế nguyên liệu khi không có sẵn
- Mẹo và kỹ thuật nấu ăn
- Tối ưu hóa thời gian và hương vị
- Tư vấn cách sử dụng nguyên liệu hiệu quả

## Cách sử dụng

### Từ Chat List
1. Mở trang **Tin nhắn**
2. Click nút **"Chef AI"** (màu tím, icon não bộ AI)
3. Bắt đầu chat!

### Câu hỏi mẫu

#### Tìm công thức
```
"Tìm giúp tôi các món bún ngon"
"Có món gì làm từ thịt bò?"
"Món chay dễ làm"
"Món soup nấu nhanh"
```

#### Gợi ý và tư vấn
```
"Tôi có cà rốt, hành tây, thịt gà, làm gì được?"
"Món healthy cho bữa trưa"
"Thay thế sữa tươi bằng gì?"
"Mẹo làm thịt mềm"
```

#### Hướng dẫn nấu
```
"Cách luộc trứng lòng đào"
"Bí quyết xào rau giòn ngon"
"Nêm nếm như thế nào cho đúng?"
```

## Technical Details

### Architecture

```
Flutter App
    ↓
AiChefService (core/services/ai_chef_service.dart)
    ↓
Firebase Functions: aiChefChat
    ↓
[Recipe Search] → Firestore recipes collection
    ↓
OpenAI GPT (với recipe context)
    ↓
Response với specific recipes
```

### Recipe Search Flow

1. **Intent Detection**: Phát hiện keywords (món, nấu, bún, phở, etc.)
2. **Keyword Extraction**: Trích xuất food-related words
3. **Firestore Query**: 
   - Query `status == 'public'`
   - Limit 50 recipes (newest first)
4. **Relevance Scoring**:
   - Title match: +10 points
   - Description match: +5 points
   - Tags match: +5 points
   - Search tokens match: +4 points
   - Ingredients tokens match: +3 points
5. **Top N Selection**: Chọn 5 recipes có score cao nhất
6. **Format for AI**: Định dạng thành context cho OpenAI

### AI Config

**Feature ID**: `chef_chat`

**Default Settings**:
- Model: `gpt-4.1-mini`
- Temperature: 0.7 (creative but controlled)
- Max Output Tokens: 800

**Prompt Template Variables**:
- `{{history}}`: Conversation history
- `{{message}}`: User's latest message
- `{{recipeContext}}`: Formatted recipe search results

### Data Structure

#### Recipe Document (Firestore)
```typescript
{
  title: string
  description: string
  ingredients: Array<{name, quantity, unit}>
  steps: Array<{description}>
  tags: string[]
  searchTokens: string[]
  ingredientsTokens: string[]
  cookingTime: number (minutes)
  servings: number
  status: 'public' | 'draft' | etc
  createdAt: Timestamp
}
```

#### Chat Session (Firestore)
```typescript
aiChats/{userId}/sessions/{sessionId}
  - createdAt: Timestamp
  - lastMessageAt: Timestamp
  - title: string (first message)
  
  messages/{messageId}
    - role: 'user' | 'assistant'
    - content: string
    - createdAt: Timestamp
```

## Best Practices

### For Users

1. **Be Specific**: "Món bún gà" tốt hơn "món ăn"
2. **Mention Constraints**: "món nhanh dưới 30 phút", "món chay"
3. **Follow Up**: Chef AI nhớ context, có thể hỏi thêm chi tiết
4. **Use Vietnamese**: AI hiểu tiếng Việt tốt hơn

### For Developers

1. **Update Search Keywords**: Thêm keywords mới vào `detectRecipeIntent()` và `extractKeywords()`
2. **Tune Scoring**: Điều chỉnh score weights trong `calculateRelevanceScore()`
3. **Optimize Query**: Hiện tại limit 50 recipes, có thể cải thiện với indexes
4. **Monitor Costs**: OpenAI API có cost, monitor usage
5. **Cache Recipes**: Có thể cache recipes phổ biến để giảm Firestore reads

## Performance Optimization

### Firestore Indexes Required
```
Collection: recipes
- status ASC, createdAt DESC
```

### Potential Improvements

1. **Vector Search**: Dùng embeddings để semantic search thay vì keyword
2. **Caching Layer**: Cache top recipes, popular queries
3. **Batch Processing**: Load nhiều recipes một lần
4. **User Preferences**: Learn từ interaction history

## Security

### Firestore Rules
```javascript
match /recipes/{recipeId} {
  allow read: if resource.data.status == 'public';
}

match /aiChats/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
  
  match /sessions/{sessionId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
    
    match /messages/{messageId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Troubleshooting

### Chef AI không phản hồi
- Check `chef_chat` config enabled trong Admin → AI Prompts
- Check Firebase Functions logs
- Verify OpenAI API key

### Không tìm thấy recipes
- Check `status: 'public'` trong Firestore
- Verify recipes có `tags`, `searchTokens`, `ingredientsTokens`
- Test với keywords đơn giản (bún, phở, gà)

### Phản hồi chậm
- Check OpenAI API latency
- Reduce number of recipes searched (currently 50)
- Optimize prompt length

## Future Enhancements

- [ ] Voice input/output
- [ ] Image recognition (photo of ingredients → recipe)
- [ ] Personalized recommendations based on user history
- [ ] Multi-language support
- [ ] Integration with Shopping List
- [ ] Nutrition calculator integration
- [ ] Step-by-step cooking timer

## Related Files

### Flutter
- `lib/features/ai/presentation/ai_assistant_page.dart` - UI
- `lib/features/ai/application/chef_ai_controller.dart` - State management
- `lib/core/services/ai_chef_service.dart` - API client

### Firebase Functions
- `functions/src/ai_chef_chat.ts` - Main logic
- `functions/src/ai_config.ts` - chef_chat config
- `functions/src/ai/openai_client.ts` - OpenAI wrapper

## Support

For issues or feature requests, contact the development team.

---

**Last Updated**: 2025-12-25
**Version**: 1.0.0
