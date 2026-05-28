/// Returns true if [cp] falls within a Unicode range that contains emoji.
bool isEmojiCodepoint(int cp) {
  return (cp >= 0x1F300 && cp <= 0x1FAFF) || // Modern emoji block
      (cp >= 0x2600 && cp <= 0x27BF) || // Misc symbols & dingbats
      (cp >= 0x2300 && cp <= 0x23FF) || // Misc technical (⏰ ⏳ etc.)
      (cp >= 0x1F000 && cp <= 0x1F0FF) || // Mahjong / dominos
      (cp >= 0x1F1E6 && cp <= 0x1F1FF); // Regional indicators (flags)
}

/// Returns true if [cp] is a modifier that combines with an adjacent emoji
/// codepoint (variation selectors, ZWJ, skin-tone modifiers, keycap combiner).
bool isEmojiModifier(int cp) {
  return cp == 0x200D || // Zero-Width Joiner
      cp == 0xFE0E || cp == 0xFE0F || // Variation Selector-15/16
      (cp >= 0x1F3FB && cp <= 0x1F3FF) || // Skin tone modifiers
      cp == 0x20E3; // Combining Enclosing Keycap
}

/// Splits [text] into emoji "grapheme groups" — a base emoji codepoint plus
/// any trailing modifiers and ZWJ-joined codepoints. Returns the runes for
/// each group in order. Skips any non-emoji runes.
List<List<int>> splitEmojiGroups(String text) {
  final runes = text.runes.toList();
  final groups = <List<int>>[];
  List<int>? current;
  for (var i = 0; i < runes.length; i++) {
    final cp = runes[i];
    final isBase = isEmojiCodepoint(cp);
    final isMod = isEmojiModifier(cp);
    if (isBase) {
      // ZWJ joins this codepoint to the previous group.
      if (current != null && current.isNotEmpty && current.last == 0x200D) {
        current.add(cp);
      } else {
        current = [cp];
        groups.add(current);
      }
    } else if (isMod && current != null) {
      current.add(cp);
    }
    // Non-emoji runes are dropped here; callers should validate first.
  }
  return groups;
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
