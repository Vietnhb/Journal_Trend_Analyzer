/// Normalizes text received from APIs before it reaches the UI.
///
/// OpenAlex titles can contain HTML, MathML, XML namespace tags, and encoded
/// entities. Flutter's [Text] widget renders those markers literally, so all
/// API-backed models should pass display text through this helper.
abstract final class AppTextSanitizer {
  static final RegExp _nonDisplayContent = RegExp(
    r'<(?:[a-z][\w.-]*:)?(?:annotation|script|style)\b[^>]*>.*?</(?:[a-z][\w.-]*:)?(?:annotation|script|style)\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _breakTags = RegExp(
    r'</?(?:[a-z][\w.-]*:)?(?:br|p|div|li|tr|td|th|math|mrow|semantics)\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _anyTag = RegExp(
    r'</?(?:[a-z][\w.-]*:)?[a-z][\w.-]*\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _numericEntity = RegExp(
    r'&#(?:x([0-9a-f]+)|([0-9]+));?',
    caseSensitive: false,
  );
  static final RegExp _namedEntity = RegExp(
    r'&([a-z][a-z0-9]+);',
    caseSensitive: false,
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'apos': "'",
    'gt': '>',
    'hellip': '…',
    'laquo': '«',
    'ldquo': '“',
    'lsquo': '‘',
    'lt': '<',
    'mdash': '—',
    'middot': '·',
    'nbsp': ' ',
    'ndash': '–',
    'quot': '"',
    'raquo': '»',
    'rdquo': '”',
    'rsquo': '’',
    'times': '×',
  };

  static String clean(Object? value, {String fallback = ''}) {
    final source = value?.toString().trim() ?? '';
    if (source.isEmpty) return fallback;

    // Decode twice because API text occasionally contains nested encodings
    // such as &amp;lt;i&amp;gt;.
    var text = source;
    for (var i = 0; i < 2; i++) {
      text = _decodeEntities(text);
    }

    text = text
        .replaceAll(_nonDisplayContent, ' ')
        .replaceAll(_breakTags, ' ')
        .replaceAll(_anyTag, ' ')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u200b', '')
        .replaceAll('\ufeff', '')
        .replaceAll(_whitespace, ' ')
        .trim();

    return text.isEmpty ? fallback : text;
  }

  static String? cleanNullable(Object? value) {
    final cleaned = clean(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Decodes entities while preserving supported markup for rich rendering.
  static String decodeMarkup(Object? value) {
    var text = value?.toString() ?? '';
    for (var i = 0; i < 2; i++) {
      text = _decodeEntities(text);
    }
    return text;
  }

  static String _decodeEntities(String value) {
    return value
        .replaceAllMapped(_numericEntity, (match) {
          final hexadecimal = match.group(1);
          final decimal = match.group(2);
          final codePoint = int.tryParse(
            hexadecimal ?? decimal ?? '',
            radix: hexadecimal == null ? 10 : 16,
          );
          if (codePoint == null ||
              codePoint < 0 ||
              codePoint > 0x10ffff ||
              (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
            return ' ';
          }
          return String.fromCharCode(codePoint);
        })
        .replaceAllMapped(_namedEntity, (match) {
          final entity = match.group(1)!.toLowerCase();
          return _namedEntities[entity] ?? match.group(0)!;
        });
  }
}
