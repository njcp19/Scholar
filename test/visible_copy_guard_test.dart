import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbiddenVisibleCopy = RegExp(
  r'\b(?:top[\s-]?up|cash[\s-]?out|paused|withdrawals?|claims?|application\s+review|register\s+fingerprint|demo|simulated)\b',
  caseSensitive: false,
);

const _literalWhitelistByPath = <String, Set<String>>{
  'lib/models/models.dart': {'simulated'},
  'lib/services/wallet_service.dart': {
    'Not enough funds for this payout. Top up the fund first.',
    'withdrawals',
    'Only active, admin-verified scholars can cash out.',
    'The amount is below the minimum cash-out.',
    'Not enough balance for this cash-out.',
    'This Cash Out request could not be verified. Please review it and try again.',
    'This request key is already associated with a different Cash Out. Check your Cash Out history before trying again.',
    'Cash-out failed: ',
    'Could not top up the fund. Try again.',
  },
  'lib/screens/admin/funding_account_screen.dart': {
    'Funding account refresh failed after successful top-up.',
    'Fund summary refresh failed after successful top-up.',
    'Fund activity refresh failed after successful top-up.',
  },
  'lib/widgets/widgets.dart': {
    'Cash-out to ',
    'simulated top-up',
    'cash out to linked account',
  },
};

class _DartStringLiteral {
  const _DartStringLiteral(this.content, this.offset);

  final String content;
  final int offset;
}

Iterable<_DartStringLiteral> _dartStringLiterals(String source) sync* {
  var index = 0;
  while (index < source.length) {
    if (source.startsWith('//', index)) {
      final lineEnd = source.indexOf('\n', index + 2);
      index = lineEnd == -1 ? source.length : lineEnd + 1;
      continue;
    }

    if (source.startsWith('/*', index)) {
      var depth = 1;
      index += 2;
      while (index < source.length && depth > 0) {
        if (source.startsWith('/*', index)) {
          depth++;
          index += 2;
        } else if (source.startsWith('*/', index)) {
          depth--;
          index += 2;
        } else {
          index++;
        }
      }
      continue;
    }

    var quoteIndex = index;
    var isRaw = false;
    if ((source[index] == 'r' || source[index] == 'R') &&
        index + 1 < source.length &&
        (source[index + 1] == "'" || source[index + 1] == '"')) {
      isRaw = true;
      quoteIndex++;
    }

    final quote = source[quoteIndex];
    if (quote != "'" && quote != '"') {
      index++;
      continue;
    }

    final isTriple = source.startsWith('$quote$quote$quote', quoteIndex);
    final delimiterLength = isTriple ? 3 : 1;
    final contentStart = quoteIndex + delimiterLength;
    var end = contentStart;
    while (end < source.length) {
      if (!isRaw && source[end] == r'\') {
        end += 2;
        continue;
      }
      if (!isRaw && source.startsWith(r'${', end)) {
        var depth = 1;
        end += 2;
        while (end < source.length && depth > 0) {
          if (source[end] == '{') depth++;
          if (source[end] == '}') depth--;
          end++;
        }
        continue;
      }
      if (source.startsWith(
        List.filled(delimiterLength, quote).join(),
        end,
      )) {
        break;
      }
      end++;
    }

    final contentEnd = end < source.length ? end : source.length;
    yield _DartStringLiteral(
      source.substring(contentStart, contentEnd),
      index,
    );
    index = end < source.length ? end + delimiterLength : source.length;
  }
}

String _withoutInterpolation(String content) {
  final result = StringBuffer();
  var index = 0;
  while (index < content.length) {
    if (content[index] != r'$' || index + 1 >= content.length) {
      result.write(content[index++]);
      continue;
    }

    if (content[index + 1] == '{') {
      var depth = 1;
      index += 2;
      while (index < content.length && depth > 0) {
        if (content[index] == '{') depth++;
        if (content[index] == '}') depth--;
        index++;
      }
      continue;
    }

    if (RegExp(r'[A-Za-z_$]').hasMatch(content[index + 1])) {
      index += 2;
      while (index < content.length &&
          RegExp(r'[A-Za-z0-9_$]').hasMatch(content[index])) {
        index++;
      }
      continue;
    }

    result.write(content[index++]);
  }
  return result.toString();
}

bool _isForbiddenUnlessWhitelisted(String path, String content) {
  if (_literalWhitelistByPath[path]?.contains(content) ?? false) {
    return false;
  }
  return _forbiddenVisibleCopy.hasMatch(content);
}

void main() {
  test('copy exceptions match only their path and exact string', () {
    expect(
      _isForbiddenUnlessWhitelisted(
        'lib/services/wallet_service.dart',
        'withdrawals',
      ),
      isFalse,
    );
    expect(
      _isForbiddenUnlessWhitelisted(
          'lib/screens/scholar_screen.dart', 'withdrawals'),
      isTrue,
    );
    expect(
      _isForbiddenUnlessWhitelisted(
        'lib/services/wallet_service.dart',
        'withdrawals are visible here',
      ),
      isTrue,
    );
    for (final forbidden in [
      'Claim',
      'Withdrawal',
      'Application Review',
      'Register fingerprint',
    ]) {
      expect(
        _isForbiddenUnlessWhitelisted(
          'lib/screens/scholar_screen.dart',
          'Visible copy: $forbidden',
        ),
        isTrue,
        reason: '$forbidden must be reported outside its exact whitelist entry',
      );
    }
  });

  test('legacy wording is absent from visible lib copy', () async {
    final violations = <String>[];

    await for (final entity in Directory('lib').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = await entity.readAsString();
      for (final literal in _dartStringLiterals(source)) {
        final content = _withoutInterpolation(literal.content);
        final line = source.substring(0, literal.offset).split('\n').length;
        final path = entity.path.replaceAll('\\', '/');

        if (_isForbiddenUnlessWhitelisted(path, content)) {
          violations.add('$path:$line: $content');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Forbidden user-facing copy in lib:\n${violations.join('\n')}',
    );
  });
}
