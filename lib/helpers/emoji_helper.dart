/// Returns true if [cp] falls within a Unicode range that contains emoji.
bool isEmojiCodepoint(int cp) {
  return (cp >= 0x1F300 && cp <= 0x1FAFF) || // Modern emoji block
      (cp >= 0x2600 && cp <= 0x27BF) || // Misc symbols & dingbats
      (cp >= 0x2300 && cp <= 0x23FF) || // Misc technical (⏰ ⏳ etc.)
      (cp >= 0x1F000 && cp <= 0x1F0FF) || // Mahjong / dominos
      (cp >= 0x1F1E6 && cp <= 0x1F1FF); // Regional indicators (flags)
}

/// Returns [raw] trimmed if it is non-empty and contains at least one emoji
/// codepoint; otherwise returns the default tag emoji `'🏷️'`.
String coerceEmoji(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '🏷️';
  for (final cp in trimmed.runes) {
    if (isEmojiCodepoint(cp)) return trimmed;
  }
  return '🏷️';
}
