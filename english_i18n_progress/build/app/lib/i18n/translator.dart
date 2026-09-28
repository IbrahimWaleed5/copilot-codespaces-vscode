// Arabic -> English runtime translator (same rules as the website: app/Support/Localization).
// Pure Dart: no Flutter imports, so it can be unit tested with `dart test`.

class ArabicRuns {
  static const String _letter =
      r'\u{0621}-\u{063A}\u{0641}-\u{064A}\u{0660}-\u{0669}\u{066E}\u{066F}\u{0671}-\u{06D3}\u{06D5}\u{06FA}-\u{06FC}\u{06FF}\u{0750}-\u{077F}\u{FB50}-\u{FDFF}\u{FE70}-\u{FEFC}';
  static const String _mark =
      r'\u{0610}-\u{061A}\u{064B}-\u{065F}\u{0670}\u{06D6}-\u{06ED}\u{0640}\u{200C}-\u{200F}';
  static const String _punct =
      r'\u{060C}\u{061B}\u{061F}\u{066A}-\u{066D}\u{06D4}.,:;!?\-\u{2013}\u{2014}()\u{00AB}\u{00BB}\u{2026}\/%';
  static const String _space = r' \t\r\n\u{00A0}\u{202F}';
  static const String _latin = r'[A-Za-z0-9][A-Za-z0-9_.@+\-\/:%]*';

  /// Arabic run that may contain Latin words/numbers when more Arabic follows.
  static final RegExp extended = RegExp(
    '[$_letter](?:[$_letter$_mark$_punct$_space]|$_latin(?=[$_space$_punct]*[$_letter]))*',
    unicode: true,
  );

  /// Arabic-only run.
  static final RegExp strict = RegExp(
    '[$_letter][$_letter$_mark$_punct$_space]*',
    unicode: true,
  );

  static final RegExp arabic = RegExp(r'[ء-يٱ-ۓ]');
  static final RegExp _spaces = RegExp(r'[\s  ]+', unicode: true);
  static final RegExp _trailingSpace = RegExp(r'[ \t\r\n  ]+$', unicode: true);
  static final RegExp _danglingOpener = RegExp(r'[(«\-–—\/]$', unicode: true);

  static String norm(String s) => s.replaceAll(_spaces, ' ').trim();

  /// Splits a match into [core, trailing] exactly like the extraction script.
  static List<String> trim(String run) {
    var core = run.replaceFirst(_trailingSpace, '');
    while (core.isNotEmpty && _danglingOpener.hasMatch(core)) {
      core = core
          .substring(0, core.length - 1)
          .replaceFirst(_trailingSpace, '');
    }
    for (final pair in const [
      [')', '('],
      ['»', '«'],
    ]) {
      while (core.isNotEmpty &&
          core.endsWith(pair[0]) &&
          _count(core, pair[0]) > _count(core, pair[1])) {
        core = core
            .substring(0, core.length - 1)
            .replaceFirst(_trailingSpace, '');
      }
    }
    return [core, run.substring(core.length)];
  }

  static int _count(String s, String ch) => ch.allMatches(s).length;
}

class ArabicTranslator {
  ArabicTranslator(this.dictionary);

  final Map<String, String> dictionary;
  final Map<String, String> _cache = <String, String>{};

  static final RegExp _finalPunct = RegExp(
    r'^(.*?)\s*([:.!?؟،؛…]+)$',
    unicode: true,
  );
  static final RegExp _separators = RegExp(
    r'(\s*[،؛؟!?;,()«»|\/–—]+\s*|\s+-\s+|\s*\n\s*|\s{2,})',
    unicode: true,
  );

  static bool hasArabic(String s) => ArabicRuns.arabic.hasMatch(s);

  /// Translates [text]; unknown parts stay exactly as they are.
  String translate(String text) {
    if (text.isEmpty || !hasArabic(text)) return text;
    final cached = _cache[text];
    if (cached != null) return cached;

    final result = text.replaceAllMapped(ArabicRuns.extended, (m) {
      final parts = ArabicRuns.trim(m[0]!);
      final core = parts[0];
      final trail = parts[1];
      if (core.isEmpty) return m[0]!;
      final en = _lookup(core);
      if (en != null) return en + trail;
      return _pieces(core) + trail;
    });

    if (_cache.length > 3000) _cache.clear();
    _cache[text] = result;
    return result;
  }

  String? _lookup(String core) {
    final key = ArabicRuns.norm(core);
    if (key.isEmpty) return null;
    final direct = dictionary[key];
    if (direct != null) return direct;
    final m = _finalPunct.firstMatch(key);
    if (m != null) {
      final base = dictionary[m[1]!];
      if (base != null) {
        return base.trimRight() + _latinPunctuation(m[2]!);
      }
    }
    return null;
  }

  String _pieces(String core) {
    // 1) Arabic-only sub-runs (the run contained numbers / Latin words)
    var changed = false;
    final sub = core.replaceAllMapped(ArabicRuns.strict, (s) {
      final parts = ArabicRuns.trim(s[0]!);
      final en = parts[0].isEmpty ? null : _lookup(parts[0]);
      if (en == null) return s[0]!;
      changed = true;
      return en + parts[1];
    });
    if (changed && !hasArabic(sub)) return _latinPunctuation(sub);

    // 1b) known phrases around a value
    final seq = _segment(core);
    if (seq != null) return _latinPunctuation(seq);

    // 2) pieces separated by punctuation / line breaks
    final buffer = StringBuffer();
    var any = false;
    var last = 0;
    for (final m in _separators.allMatches(core)) {
      final piece = core.substring(last, m.start);
      final en = piece.trim().isEmpty
          ? null
          : (_lookup(piece) ?? _segment(piece));
      buffer.write(en ?? piece);
      if (en != null) any = true;
      buffer.write(m[0]);
      last = m.end;
    }
    if (last == 0) return changed ? sub : core;
    final tail = core.substring(last);
    final enTail = tail.trim().isEmpty
        ? null
        : (_lookup(tail) ?? _segment(tail));
    buffer.write(enTail ?? tail);
    if (enTail != null) any = true;
    if (!any) return changed ? sub : core;
    final joined = buffer.toString();
    return hasArabic(joined) ? joined : _latinPunctuation(joined);
  }

  /// All-or-nothing split into known phrases (max 3 pieces, longest Arabic piece 3+ words).
  String? _segment(String core) {
    final words = core.trim().split(RegExp(r'\s+'));
    final n = words.length;
    if (n < 2 || n > 60) return null;
    final pieces = List<int?>.filled(n + 1, null);
    final texts = List<String?>.filled(n + 1, null);
    final longest = List<int>.filled(n + 1, 0);
    pieces[0] = 0;
    texts[0] = '';
    for (var i = 1; i <= n; i++) {
      for (var j = i - 14 < 0 ? 0 : i - 14; j < i; j++) {
        if (pieces[j] == null) continue;
        final phrase = words.sublist(j, i).join(' ');
        var en = _lookup(phrase);
        if (en == null && i - j == 1 && !hasArabic(phrase)) en = phrase;
        if (en == null) continue;
        final count = pieces[j]! + 1;
        final len = hasArabic(phrase) && (i - j) > longest[j]
            ? i - j
            : longest[j];
        if (pieces[i] == null ||
            count < pieces[i]! ||
            (count == pieces[i]! && len > longest[i])) {
          pieces[i] = count;
          longest[i] = len;
          texts[i] = j == 0 ? en : '${texts[j]!.trimRight()} $en';
        }
      }
    }
    if (pieces[n] == null || pieces[n]! > 3 || longest[n] < 3) return null;
    return texts[n];
  }

  static String _latinPunctuation(String s) =>
      s.replaceAll('،', ',').replaceAll('؛', ';').replaceAll('؟', '?');
}
