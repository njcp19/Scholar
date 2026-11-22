import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

void main() {
  test('legacy wording is absent from visible lib copy', () async {
    final forbiddenVisibleCopy = RegExp(
      r'\b(?:top[\s-]?up|cash[\s-]?out|paused|withdrawals?|claims?|application\s+review|register\s+fingerprint|demo|simulated)\b',
      caseSensitive: false,
    );
    const nonVisibleLiteralWhitelist = {
      'lib/models/models.dart:503': 'simulated',
      'lib/services/wallet_service.dart:129':
          'Not enough funds for this payout. Top up the fund first.',
      'lib/services/wallet_service.dart:394': 'withdrawals',
      'lib/services/wallet_service.dart:407':
          'Only active, admin-verified scholars can cash out.',
      'lib/services/wallet_service.dart:415':
          'The amount is below the minimum cash-out.',
      'lib/services/wallet_service.dart:417':
          'Not enough balance for this cash-out.',
      'lib/services/wallet_service.dart:419':
          'This Cash Out request could not be verified. Please review it and try again.',
      'lib/services/wallet_service.dart:421':
          'This request key is already associated with a different Cash Out. Check your Cash Out history before trying again.',
      'lib/services/wallet_service.dart:426': 'Cash-out failed: ',
      'lib/services/wallet_service.dart:471':
          'Could not top up the fund. Try again.',
      'lib/services/wallet_service.dart:515':
          'Not enough funds for this payout. Top up the fund first.',
      'lib/screens/admin/funding_account_screen.dart:136':
          'Funding account refresh failed after successful top-up.',
      'lib/screens/admin/funding_account_screen.dart:142':
          'Fund summary refresh failed after successful top-up.',
      'lib/screens/admin/funding_account_screen.dart:148':
          'Fund activity refresh failed after successful top-up.',
      'lib/widgets/widgets.dart:21': 'Cash-out to ',
      'lib/widgets/widgets.dart:30': 'simulated top-up',
      'lib/widgets/widgets.dart:31': 'cash out to linked account',
    };
    final violations = <String>[];

    await for (final entity in Directory('lib').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = await entity.readAsString();
      for (final literal in _dartStringLiterals(source)) {
        final content = _withoutInterpolation(literal.content);
        final line = source.substring(0, literal.offset).split('\n').length;
        final path = entity.path.replaceAll('\\', '/');
        if (nonVisibleLiteralWhitelist['$path:$line'] == content) continue;

        if (forbiddenVisibleCopy.hasMatch(content)) {
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
