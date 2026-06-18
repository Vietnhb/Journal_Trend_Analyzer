import 'package:flutter/material.dart';

import '../constants/app_text_sanitizer.dart';

/// Renders the small HTML/MathML subset commonly found in publication titles.
///
/// Supported semantic tags: i/em, b/strong, u, sub, sup, small, br, plus
/// common MathML msub/msup/msubsup structures. Unknown tags are ignored while
/// their text remains visible.
class AppMarkupText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool softWrap;

  const AppMarkupText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.softWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(children: _MarkupParser(text, baseStyle).parse()),
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}

class _MarkupParser {
  static final RegExp _token = RegExp(r'<[^>]*>|[^<]+', dotAll: true);
  static final RegExp _tagName = RegExp(
    r'^<\s*(/?)\s*(?:[a-z][\w.-]*:)?([a-z][\w.-]*)',
    caseSensitive: false,
  );
  static final RegExp _nonDisplayContent = RegExp(
    r'<(?:[a-z][\w.-]*:)?(?:annotation|script|style)\b[^>]*>.*?</(?:[a-z][\w.-]*:)?(?:annotation|script|style)\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _mSubSup = RegExp(
    r'<(?:[a-z][\w.-]*:)?msubsup\b[^>]*>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'</(?:[a-z][\w.-]*:)?msubsup\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _mSub = RegExp(
    r'<(?:[a-z][\w.-]*:)?msub\b[^>]*>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'</(?:[a-z][\w.-]*:)?msub\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _mSup = RegExp(
    r'<(?:[a-z][\w.-]*:)?msup\b[^>]*>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'<(?:[a-z][\w.-]*:)?mi\b[^>]*>(.*?)</(?:[a-z][\w.-]*:)?mi>\s*'
    r'</(?:[a-z][\w.-]*:)?msup\s*>',
    caseSensitive: false,
    dotAll: true,
  );

  final String source;
  final TextStyle baseStyle;

  _MarkupParser(this.source, this.baseStyle);

  List<InlineSpan> parse() {
    var markup = AppTextSanitizer.decodeMarkup(source)
        .replaceAll(_nonDisplayContent, '')
        .replaceAllMapped(
          _mSubSup,
          (match) =>
              '${match.group(1)}<sub>${match.group(2)}</sub>'
              '<sup>${match.group(3)}</sup>',
        )
        .replaceAllMapped(
          _mSub,
          (match) => '${match.group(1)}<sub>${match.group(2)}</sub>',
        )
        .replaceAllMapped(
          _mSup,
          (match) => '${match.group(1)}<sup>${match.group(2)}</sup>',
        );

    // Some source titles omit whitespace immediately after a closing tag.
    markup = markup.replaceAllMapped(
      RegExp(r'(</[^>]+>)(?=[\p{L}\p{N}])', unicode: true),
      (match) => '${match.group(1)} ',
    );

    final spans = <InlineSpan>[];
    final styles = <TextStyle>[baseStyle];
    final tags = <String>[];

    for (final token
        in _token.allMatches(markup).map((match) => match.group(0)!)) {
      if (!token.startsWith('<')) {
        final value = AppTextSanitizer.decodeMarkup(
          token,
        ).replaceAll('\u00a0', ' ').replaceAll('\u200b', '');
        if (value.isNotEmpty) {
          spans.add(TextSpan(text: value, style: styles.last));
        }
        continue;
      }

      final tagMatch = _tagName.firstMatch(token);
      if (tagMatch == null) continue;
      final isClosing = tagMatch.group(1)!.isNotEmpty;
      final tag = tagMatch.group(2)!.toLowerCase();

      if (tag == 'br' && !isClosing) {
        spans.add(TextSpan(text: '\n', style: styles.last));
        continue;
      }
      if (!_isStyledTag(tag)) continue;

      if (isClosing) {
        final index = tags.lastIndexOf(tag);
        if (index < 0) continue;
        while (tags.length > index) {
          tags.removeLast();
          styles.removeLast();
        }
      } else if (!token.endsWith('/>')) {
        tags.add(tag);
        styles.add(_styleFor(tag, styles.last));
      }
    }

    if (spans.isEmpty) {
      return [TextSpan(text: AppTextSanitizer.clean(source), style: baseStyle)];
    }
    return spans;
  }

  bool _isStyledTag(String tag) {
    return const {
      'b',
      'em',
      'i',
      'small',
      'strong',
      'sub',
      'sup',
      'u',
    }.contains(tag);
  }

  TextStyle _styleFor(String tag, TextStyle current) {
    final fontSize = current.fontSize ?? baseStyle.fontSize ?? 14;
    return switch (tag) {
      'b' || 'strong' => current.copyWith(fontWeight: FontWeight.bold),
      'i' || 'em' => current.copyWith(fontStyle: FontStyle.italic),
      'u' => current.copyWith(decoration: TextDecoration.underline),
      'small' => current.copyWith(fontSize: fontSize * 0.85),
      'sub' => current.copyWith(
        fontSize: fontSize * 0.75,
        fontFeatures: const [FontFeature.subscripts()],
      ),
      'sup' => current.copyWith(
        fontSize: fontSize * 0.75,
        fontFeatures: const [FontFeature.superscripts()],
      ),
      _ => current,
    };
  }
}
