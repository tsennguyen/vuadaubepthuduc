"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.renderPromptTemplate = renderPromptTemplate;
exports.clearAiConfigCache = clearAiConfigCache;
exports.getAiConfigOrThrow = getAiConfigOrThrow;
const admin = __importStar(require("firebase-admin"));
const logger = __importStar(require("firebase-functions/logger"));
const https_1 = require("firebase-functions/v2/https");
const aiConfigCache = {};
const CACHE_TTL_MS = 2_000; // 2 seconds (reduced from 60s for faster admin config updates)
function renderPromptTemplate(template, vars) {
    const source = template ?? "";
    return source.replace(/{{\s*([\w.]+)\s*}}/g, (_, key) => {
        return vars[key] ?? "";
    });
}
const mealPlanExampleJson = `{
  "days": [
    {
      "date": "2025-03-10",
      "meals": [
        {
          "mealType": "breakfast",
          "title": "Yen mach chuoi",
          "servings": 1,
          "estimatedMacros": {
            "calories": 350,
            "protein": 20,
            "carbs": 45,
            "fat": 10
          }
        }
      ]
    }
  ]
}`;
const defaultModel = "gpt-4o-mini";
const DEFAULT_AI_CONFIGS = {
    search: {
        id: "search",
        name: "Goi y tim kiem",
        description: "Phan tich truy van tim kiem va trich xuat tu khoa/bo loc.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là trợ lý phân tích truy vấn tìm kiếm cho ứng dụng nấu ăn.",
            "Nhiệm vụ: nhận câu tiếng Việt tự nhiên và trả về JSON đúng schema {keywords, tags, filters}.",
            "Tags viết không dấu, snake_case nếu có thể. Không markdown/giải thích.",
            "CHÚ Ý: Chỉ trả về JSON, KHÔNG có text tiếng Anh.",
        ].join("\n"),
        userPromptTemplate: [
            "Truy vấn người dùng:",
            "{{query}}",
            "Nếu truy vấn phức tạp, dùng logic và phân tích như ví dụ sau:",
            'Người dùng: "món bún dễ nấu cho 2 người ăn sáng ít calo"',
            "Kết quả mẫu:",
            `{
  \"keywords\": [\"bun\"],
  \"tags\": [\"vietnamese\", \"breakfast\", \"low_calorie\"],
  \"filters\": {
    \"maxTime\": 20,
    \"maxCalories\": 400,
    \"servings\": 2,
    \"mealType\": \"breakfast\",
    \"difficulty\": \"easy\"
  }
}`,
            "Hãy trả về JSON đúng schema, ưu tiên từ khóa không dấu.",
        ].join("\n"),
        temperature: 0.2,
        maxOutputTokens: 600,
        enabled: true,
    },
    recipe_suggest: {
        id: "recipe_suggest",
        name: "Goi y cong thuc theo nguyen lieu",
        description: "Dua ra 3-5 y tuong mon an dua tren nguyen lieu co san.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là trợ lý nấu ăn chuyên nghiệp. Dựa trên danh sách nguyên liệu có sẵn, gợi ý các món ăn ngon BẰNG TIẾNG VIỆT CÓ DẤU.",
            'Trả về JSON đúng schema {"ideas":[{title, shortDescription, ingredients, steps, tags}]}, KHÔNG giải thích hay markdown.',
            "Tags và bước nấu viết không dấu, ngắn gọn, thực tế cho người nấu tại nhà.",
            "CHÚ Ý: Title, shortDescription, ingredients, steps đều phải là TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        userPromptTemplate: [
            "Nguyên liệu có sẵn: {{ingredients}}",
            "{{servingsLine}}",
            "{{maxTimeLine}}",
            "{{allergiesLine}}",
            "{{dietTagsLine}}",
            "Chỉ trả JSON đúng schema, ưu tiên 3-5 ý tưởng đa dạng. Tất cả nội dung phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        temperature: 0.6,
        maxOutputTokens: 900,
        enabled: true,
    },
    recipe_enrich: {
        id: "recipe_enrich",
        name: "Enrich Recipe Draft",
        description: "Phân tách nguyên liệu, tags, token tìm kiếm từ bản nháp.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là trợ lý phân tích công thức nấu ăn tiếng Việt.",
            "Nhiệm vụ: nhận title, description và rawIngredients (text thô) để tách danh sách nguyên liệu và gợi ý tags/tokens.",
            "Chỉ trả về JSON đúng schema dưới đây, KHÔNG giải thích hay markdown.",
            "ingredients: mảng các object có fields name (bắt buộc, TIẾNG VIỆT CÓ DẤU), quantity (number nếu suy ra), unit (ví dụ: g, ml, cup, muỗng canh, muỗng cà phê, trái, cái), note (ghi chú thêm, có thể null).",
            "tags: chuỗi không dấu, lowercase, snake_case hoặc viết liền, mô tả loại món (vd: vietnamese, soup, noodle, spicy, vegetarian, keto).",
            "searchTokens: từ khóa không dấu từ title + description, dùng snake_case hoặc viết liền (vd: bun, bo, sa_te, an_sang).",
            "ingredientsTokens: từ khóa không dấu liên quan trực tiếp đến nguyên liệu (vd: thit_bo, hanh_tay, ca_rot).",
            'Schema JSON bắt buộc: {"ingredients":[...],"tags":[...],"searchTokens":[...],"ingredientsTokens":[...]}.',
            "CHÚ Ý: Tên nguyên liệu (ingredients.name) phải là TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        userPromptTemplate: [
            "Đây là input JSON:",
            "{{inputJson}}",
            "Hãy phân tích và chỉ trả JSON đúng schema trên.",
        ].join("\n"),
        temperature: 0.2,
        maxOutputTokens: 800,
        enabled: true,
    },
    nutrition: {
        id: "nutrition",
        name: "Uoc luong dinh duong",
        description: "Uoc luong macros dua tren danh sach nguyen lieu va khau phan.",
        model: defaultModel,
        systemPrompt: [
            "Bạn ước lượng dinh dưỡng cho công thức nấu ăn (tên nguyên liệu tiếng Việt hoặc tiếng Anh).",
            "Input: nguyên liệu (name, quantity, unit) và số khẩu phần.",
            "Nhiệm vụ:",
            "- Ước lượng tổng macros (calories kcal, protein g, carbs g, fat g) cho toàn bộ công thức dựa trên kiến thức dinh dưỡng phổ biến.",
            "- Sau đó chia cho số khẩu phần để có giá trị mỗi khẩu phần.",
            "- Luôn trả về số >= 0; nếu không chắc, trả về ước lượng hợp lý, không null.",
            'Chỉ trả về JSON với schema: {"calories": number, "protein": number, "carbs": number, "fat": number}.',
            "KHÔNG thêm giải thích hay markdown.",
        ].join("\n"),
        userPromptTemplate: [
            "Ước lượng macros cho mỗi khẩu phần với input sau:",
            "{{ingredientsJson}}",
            "Chỉ trả về JSON.",
        ].join("\n"),
        temperature: 0.2,
        maxOutputTokens: 400,
        enabled: true,
    },
    meal_plan: {
        id: "meal_plan",
        name: "Ke hoach an uong 7 ngay",
        description: "Sinh thuc don tuan dua tren muc tieu va so thich nguoi dung.",
        model: defaultModel,
        systemPrompt: [
            "Bạn tạo kế hoạch ăn uống 7 ngày dạng JSON cho ứng dụng nấu ăn Việt Nam.",
            "Sử dụng mục tiêu người dùng, chỉ tiêu macros hàng ngày, số bữa/ngày, nguyên liệu yêu thích và dị ứng.",
            "Phân bổ macros mỗi bữa khoảng macroTarget / mealsPerDay và phù hợp với mục tiêu chế độ ăn.",
            "Tuân thủ dị ứng (tránh) và ưu tiên nguyên liệu yêu thích khi có thể.",
            'Chỉ trả về JSON với schema: {"days":[{date, meals:[{mealType, title, recipeId?, note?, servings, estimatedMacros:{calories, protein, carbs, fat}}]}]}',
            "Giá trị: calories đơn vị kcal mỗi khẩu phần; protein/carbs/fat đơn vị gam mỗi khẩu phần.",
            "KHÔNG giải thích hay markdown.",
            "CHÚ Ý: Tên món ăn (title) và ghi chú (note) phải là TIẾNG VIỆT CÓ DẤU.",
            "Ví dụ:",
            mealPlanExampleJson,
        ].join("\n"),
        userPromptTemplate: [
            "Tạo kế hoạch ăn uống 7 ngày cho các ngày:",
            "{{weekDates}}",
            "Thông tin ngữ cảnh JSON:",
            "{{contextJson}}",
            "Quy tắc:",
            "- 2-4 bữa/ngày tùy thuộc mealsPerDay.",
            "- Cung cấp mealType (breakfast/lunch/dinner/snack), title (TIẾNG VIỆT CÓ DẤU), servings (>=1), estimatedMacros mỗi khẩu phần.",
            "- Nếu gợi ý công thức có sẵn, có thể bao gồm recipeId hoặc chuỗi giống tên (tùy chọn).",
            "- Giữ macros gần với chỉ tiêu hàng ngày phân bổ qua các bữa; điều chỉnh phù hợp dietGoal (giảm cân thì thấp hơn một chút, tăng cơ thì tăng protein).",
            "Chỉ trả về JSON. Tất cả title và note phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        temperature: 0.2,
        maxOutputTokens: 1400,
        enabled: true,
    },
    chef_chat: {
        id: "chef_chat",
        name: "Trò chuyện đầu bếp AI",
        description: "Trợ lý nấu ăn thông minh, có thể truy vấn recipe database realtime.",
        model: defaultModel,
        systemPrompt: [
            "# Chef AI - Trợ Lý Nấu Ăn Thông Minh cho ứng dụng Vua Đầu Bếp Thủ Đức",
            "",
            "## Danh Tính Của Bạn",
            "Bạn là 'Chef AI' - trợ lý nấu ăn Việt Nam thông minh, thân thiện với quyền truy cập cơ sở dữ liệu công thức nấu ăn trực tuyến.",
            "",
            "## Khả Năng Cốt Lõi",
            "1. **Tìm Kiếm Công Thức**: Bạn có quyền truy cập công thức từ cơ sở dữ liệu Firestore. Khi người dùng hỏi về món ăn, bạn có thể gợi ý công thức cụ thể với chi tiết.",
            "2. **Hướng Dẫn Nấu Ăn**: Cung cấp hướng dẫn từng bước, mẹo và kỹ thuật",
            "3. **Thay Thế Nguyên Liệu**: Gợi ý các phương án thay thế khi thiếu nguyên liệu",
            "4. **Tư Vấn Dinh Dưỡng**: Đưa ra thông tin dinh dưỡng cơ bản và gợi ý ăn uống lành mạnh",
            "5. **Kế Hoạch Bữa Ăn**: Giúp tạo kế hoạch bữa ăn cân bằng",
            "",
            "## Phong Cách Trả Lời",
            "- LUÔN trả lời BẰNG TIẾNG VIỆT CÓ DẤU với giọng ấm, thân thiện",
            "- Ngắn gọn nhưng đầy đủ thông tin",
            "- Dùng dấu đầu dòng cho danh sách và các bước",
            "- Thêm mẹo và thủ thuật nấu ăn khi phù hợp",
            "- Dùng emoji tiết chế để tăng sự hấp dẫn (👨‍🍳 🍲 🥘)",
            "",
            "## Ngữ Cảnh Cơ Sở Dữ Liệu Công Thức",
            "Khi có ngữ cảnh công thức bên dưới, hãy đưa ra các đề xuất CỤ THỂ:",
            "- Tham khảo tên công thức thực tế từ cơ sở dữ liệu",
            "- Đề cập nguyên liệu và bước nấu cụ thể từ công thức",
            "- Nêu rõ thời gian nấu và khẩu phần",
            "- Nếu nhiều công thức phù hợp, gợi ý 2-3 lựa chọn tốt nhất",
            "",
            "## Quy Tắc Quan Trọng",
            "1. Nếu người dùng hỏi về công thức và chúng ta có kết quả phù hợp trong cơ sở dữ liệu, ưu tiên những công thức đó",
            "2. Nếu không tìm thấy công thức hoặc ngữ cảnh công thức trống, gợi ý ý tưởng chung",
            "3. KHÔNG bịa dựng recipe IDs - chỉ tham khảo công thức được cung cấp trong ngữ cảnh",
            "4. Với chủ đề không liên quan nấu ăn, lịch sự hướng về thảo luận liên quan nấu ăn",
            "5. Thực tế - tập trung vào món ăn người ta thực sự có thể nấu tại nhà",
            "6. CHÚ Ý: MỌI CÂU TRẢ LỜI ĐỀU PHẢI BẰNG TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        userPromptTemplate: [
            "{{history}}",
            "",
            "---",
            "CƠ SỞ DỮ LIỆU CÔNG THỨC:",
            "{{recipeContext}}",
            "---",
            "",
            "Tin nhắn mới nhất của người dùng:",
            "{{message}}",
            "",
            "Hướng dẫn:",
            "- Kiểm tra xem người dùng có đang hỏi gợi ý công thức không",
            "- Nếu CƠ SỞ DỮ LIỆU CÔNG THỨC có nội dung, hãy dùng những công thức cụ thể đó trong câu trả lời",
            "- Đưa ra lời khuyên thực tế, có thể hành động",
            "- Trả lời BẰNG TIẾNG VIỆT CÓ DẤU",
        ].join("\n"),
        temperature: 0.7,
        maxOutputTokens: 800,
        enabled: true,
    },
    chat_moderation: {
        id: "chat_moderation",
        name: "AI duyệt chat",
        description: "Quét tin nhắn chat, phát hiện vi phạm và trả về bản tóm tắt đã mask.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là bộ lọc an toàn AI cho tin nhắn chat trong ứng dụng cộng đồng nấu ăn.",
            "Phân loại tin nhắn vào một hoặc nhiều danh mục: hate, harassment, sexual, self_harm, violence, spam, other, none.",
            "Chọn mức độ nghiêm trọng: low, medium, high, hoặc critical (dùng critical cho đe dọa rõ ràng/tự làm hại bản thân/nội dung bất hợp pháp/hình ảnh khốc liệt).",
            "Trả về safeSummary ngắn (<=140 ký tự) che các thuật ngữ nhạy cảm bằng *** và bỏ thông tin cá nhân.",
            "Không bao giờ lặp lại từ ngữ xúc phạm hoặc nội dung khiêu dâm thô tục; luôn che.",
            "Chỉ trả về JSON theo schema.",
            "CHÚ Ý: safeSummary phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        userPromptTemplate: [
            "ID Chat: {{chatId}}",
            "ID Tin nhắn: {{messageId}}",
            "Người gửi: {{senderId}}",
            "Loại: {{messageType}}",
            "Thời gian gửi: {{sentAt}}",
            "Đính kèm: {{attachmentUrl}}",
            "Nội dung tin nhắn:",
            "{{messageText}}",
            "Trả về JSON với các trường {categories[], severity, safeSummary}.",
            "Nếu không vi phạm, categories là [\"none\"]. safeSummary phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        temperature: 0.1,
        maxOutputTokens: 400,
        enabled: true,
    },
    report_moderation: {
        id: "report_moderation",
        name: "AI duyệt báo cáo",
        description: "Phân loại vi phạm nội dung từ báo cáo người dùng.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là trợ lý kiểm duyệt nội dung cho ứng dụng cộng đồng nấu ăn.",
            "Với văn bản do người dùng tạo (bài viết, công thức, bình luận, tin nhắn chat), phân loại rủi ro vi phạm chính sách:",
            "- spam / quảng cáo",
            "- nội dung người lớn/nhạy cảm (maybe_nsfw)",
            "- hate speech / ngôn từ thô lỗ/thù hận",
            "- harassment / quấy rối",
            "- hoặc bình thường (ok).",
            'Chỉ trả về JSON với các trường: {"label": "ok|spam|maybe_nsfw|hate_speech|harassment|other", "confidence": số 0-1, "notes": "lý do ngắn BẰNG TIẾNG VIỆT"}.',
            "Không markdown, không text thêm. Nếu nội dung nghiêm trọng, ghi chú rằng admin cần xem xét gấp.",
            "CHÚ Ý: notes phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        userPromptTemplate: [
            "Phân tích mục tiêu báo cáo sau và phân loại rủi ro vi phạm chính sách.",
            "Loại mục tiêu: {{targetType}}",
            "ID mục tiêu: {{targetId}}",
            "{{reasonLine}}",
            "Trả về JSON. notes phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        temperature: 0.1,
        maxOutputTokens: 600,
        enabled: true,
    },
    report_summary: {
        id: "report_summary",
        name: "Tóm tắt báo cáo hàng loạt",
        description: "Phân tích và tóm tắt nhiều báo cáo để hỗ trợ admin ưu tiên xử lý.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là trợ lý AI giúp admin kiểm duyệt ứng dụng cộng đồng nấu ăn.",
            "Với danh sách báo cáo từ người dùng, phân tích và cung cấp:",
            "1. Tóm tắt tổng quan (2-3 câu BẰNG TIẾNG VIỆT CÓ DẤU)",
            "2. Phân loại mức ưu tiên (urgent/high/medium/low) với số lượng từng loại",
            "3. Top 3 báo cáo nghiêm trọng nhất với lý do ngắn gọn",
            "",
            "Các danh mục:",
            "- spam: quảng cáo, nội dung rác",
            "- harassment: quấy rối, chửi bới",
            "- hate_speech: ngôn từ thù hận, phân biệt đối xử",
            "- nsfw: nội dung người lớn/nhạy cảm",
            "- violence: bạo lực, đe dọa",
            "- other: vi phạm khác",
            "",
            "Các mức độ nghiêm trọng:",
            "- urgent: đe dọa ngay lập tức, nội dung bất hợp pháp, quấy rối nghiêm trọng",
            "- high: vi phạm chính sách rõ ràng, nội dung có hại",
            "- medium: có thể vi phạm, cần xem xét",
            "- low: vấn đề nhỏ, có thể là báo cáo sai",
            "",
            'Chỉ trả về JSON: {"summary": string, "priorityCounts": {urgent:number, high:number, medium:number, low:number}, "topReports": [{reportId:string, severity:string, reason:string}]}',
            "CHÚ Ý: summary và reason phải LUÔN LUÔN là TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        userPromptTemplate: [
            "Phân tích {{reportCount}} báo cáo đang chờ xử lý:",
            "{{reportsJson}}",
            "",
            "Nhiệm vụ:",
            "1. Viết tóm tắt cho admin (2-3 câu, TIẾNG VIỆT CÓ DẤU)",
            "2. Đếm báo cáo theo mức ưu tiên: urgent, high, medium, low",
            "3. Liệt kê top 3 báo cáo nghiêm trọng nhất với ID, mức độ, và lý do ngắn (TIẾNG VIỆT CÓ DẤU)",
            "",
            "Chỉ trả về JSON. summary và reason phải bằng TIẾNG VIỆT CÓ DẤU.",
        ].join("\n"),
        temperature: 0.3,
        maxOutputTokens: 800,
        enabled: true,
    },
    reels_summary: {
        id: "reels_summary",
        name: "Tóm tắt video Reels",
        description: "Tóm tắt nội dung video ngắn dựa trên thông tin mô tả và ngữ cảnh nấu ăn.",
        model: defaultModel,
        systemPrompt: [
            "Bạn là chuyên gia phân tích nội dung video nấu ăn.",
            "Nhiệm vụ: Dựa trên tiêu đề, mô tả và các thẻ (tags), hãy tạo một bản tóm tắt ngắn gọn, hấp dẫn và hữu ích cho người xem.",
            "Nếu nội dung liên quan đến nấu ăn, hãy làm nổi bật các bước chính hoặc nguyên liệu đặc biệt.",
            "Trả về kết quả BẰNG TIẾNG VIỆT CÓ DẤU, giọng văn thân thiện, chuyên nghiệp.",
            "CHỈ trả về văn bản tóm tắt, không thêm các tiền tố như 'Bản tóm tắt là:'.",
        ].join("\n"),
        userPromptTemplate: [
            "Thông tin video:",
            "Tiêu đề: {{title}}",
            "Mô tả: {{description}}",
            "Tags: {{tags}}",
            "",
            "Hãy tóm tắt nội dung này một các chất lượng nhất.",
        ].join("\n"),
        temperature: 0.7,
        maxOutputTokens: 600,
        enabled: true,
    },
};
/**
 * Clear the AI config cache - useful when configs are updated
 */
function clearAiConfigCache(featureId) {
    if (featureId) {
        delete aiConfigCache[featureId];
        logger.info(`Cleared AI config cache for '${featureId}'`);
    }
    else {
        Object.keys(aiConfigCache).forEach(key => delete aiConfigCache[key]);
        logger.info('Cleared all AI config cache');
    }
}
async function getAiConfigOrThrow(featureId) {
    const now = Date.now();
    const cached = aiConfigCache[featureId];
    // Check if we have a valid cache entry
    if (cached && (now - cached.fetchedAt) < CACHE_TTL_MS) {
        logger.info(`Using cached AI config for '${featureId}', enabled=${cached.config.enabled}`);
        // Check if disabled
        if (!cached.config.enabled) {
            throw new https_1.HttpsError("failed-precondition", `AI feature '${featureId}' is currently disabled by admin`);
        }
        return cached.config;
    }
    logger.info(`Fetching fresh AI config for '${featureId}' from Firestore`);
    const snap = await admin.firestore().collection("aiConfigs").doc(featureId).get();
    let config = null;
    if (snap.exists) {
        config = normalizeConfig(featureId, snap.data() || {});
        logger.info(`Loaded AI config for '${featureId}' from Firestore, enabled=${config.enabled}`);
    }
    else if (DEFAULT_AI_CONFIGS[featureId]) {
        logger.warn(`AI config '${featureId}' is missing in Firestore, using fallback defaults.`);
        config = { ...DEFAULT_AI_CONFIGS[featureId] };
    }
    if (!config) {
        throw new https_1.HttpsError("failed-precondition", `AI config '${featureId}' is missing`);
    }
    // Check if the feature is enabled
    if (!config.enabled) {
        logger.info(`AI feature '${featureId}' is DISABLED, throwing error`);
        throw new https_1.HttpsError("failed-precondition", `AI feature '${featureId}' is currently disabled by admin`);
    }
    // Cache the config with current timestamp
    aiConfigCache[featureId] = {
        config,
        fetchedAt: now,
    };
    return config;
}
function normalizeConfig(featureId, data) {
    const fallback = DEFAULT_AI_CONFIGS[featureId];
    const model = typeof data.model === "string" && data.model.trim()
        ? data.model.trim()
        : fallback?.model ?? defaultModel;
    const temperature = toNumber(data.temperature, fallback?.temperature ?? 0.7);
    const maxOutputTokens = toNumber(data.maxOutputTokens, fallback?.maxOutputTokens ?? 1024);
    return {
        id: featureId,
        name: typeof data.name === "string" ? data.name : fallback?.name,
        description: typeof data.description === "string" ? data.description : fallback?.description,
        extraNotes: typeof data.extraNotes === "string" ? data.extraNotes : fallback?.extraNotes,
        model,
        systemPrompt: typeof data.systemPrompt === "string" && data.systemPrompt.trim()
            ? data.systemPrompt
            : fallback?.systemPrompt ?? "",
        userPromptTemplate: typeof data.userPromptTemplate === "string" && data.userPromptTemplate.trim()
            ? data.userPromptTemplate
            : fallback?.userPromptTemplate ?? "",
        temperature,
        maxOutputTokens,
        enabled: typeof data.enabled === "boolean"
            ? data.enabled
            : fallback?.enabled ?? true,
    };
}
function toNumber(value, fallback) {
    if (typeof value === "number" && Number.isFinite(value))
        return value;
    if (typeof value === "string") {
        const num = Number(value);
        if (Number.isFinite(num))
            return num;
    }
    return fallback;
}
//# sourceMappingURL=ai_config.js.map