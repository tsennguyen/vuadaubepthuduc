String removeVietnameseDiacritics(String str) {
  var result = str.toLowerCase();
  result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
  result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
  result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
  result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
  result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
  result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
  result = result.replaceAll(RegExp(r'[đ]'), 'd');
  return result;
}

String normalizeQuery(String input) {
  return removeVietnameseDiacritics(input)
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .trim();
}

List<String> tokenize(String input) {
  final normalized = normalizeQuery(input);
  final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  return tokens.toSet().toList();
}

List<String> buildIngredientsTokens(List<String> ingredients) {
  final String merged = ingredients.join(' ');
  return tokenize(merged);
}

List<String> buildSearchTokens({
  required String title,
  required List<String> tags,
  List<String>? extra,
}) {
  final List<String> items = [
    title,
    ...tags,
    if (extra != null) ...extra,
  ];
  
  // To support both accented and non-accented search, we can combine tokens
  // For now, following user request: "không phân biệt có dấu hay không"
  // we normalize everything to non-accented.
  return tokenize(items.join(' '));
}
