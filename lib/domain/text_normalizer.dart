class TextNormalizer {
  const TextNormalizer();

  String normalize(String input) {
    final lower = input.toLowerCase().trim();
    final kana = lower.runes.map(_katakanaToHiragana).join();
    final folded = kana.split('').map(_foldAccent).join();
    return folded.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _katakanaToHiragana(int rune) {
    if (rune >= 0x30A1 && rune <= 0x30F6) {
      return String.fromCharCode(rune - 0x60);
    }
    return String.fromCharCode(rune);
  }

  String _foldAccent(String character) {
    const table = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    return table[character] ?? character;
  }
}
