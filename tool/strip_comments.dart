// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) {
  final write = args.contains('--write');
  final root = Directory('lib');

  if (!root.existsSync()) {
    stderr.writeln('Run this from the repository root.');
    exitCode = 1;
    return;
  }

  var files = 0;
  var linesBefore = 0;
  var linesAfter = 0;

  for (final file
      in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
    final source = file.readAsStringSync();
    final stripped = _collapseBlankLines(_stripComments(source));

    if (stripped == source) continue;

    files++;
    linesBefore += '\n'.allMatches(source).length;
    linesAfter += '\n'.allMatches(stripped).length;

    if (write) file.writeAsStringSync(stripped);
  }

  print(
    write
        ? 'Stripped $files files: $linesBefore lines -> $linesAfter.'
        : 'Would strip $files files: $linesBefore lines -> $linesAfter. '
              'Pass --write to apply.',
  );

  if (write) {
    print('Now run: dart format lib && flutter analyze');
  }
}

String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;

  while (i < source.length) {
    final char = source[i];

    if ((char == 'r') &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"')) {
      final end = _skipString(source, i + 1, raw: true);
      out.write(source.substring(i, end));
      i = end;
      continue;
    }

    if (char == "'" || char == '"') {
      final end = _skipString(source, i, raw: false);
      out.write(source.substring(i, end));
      i = end;
      continue;
    }

    if (char == '/' && i + 1 < source.length) {
      final next = source[i + 1];

      if (next == '/') {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        continue;
      }

      if (next == '*') {
        var depth = 0;
        while (i < source.length) {
          if (source.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (source.startsWith('*/', i)) {
            depth--;
            i += 2;
            if (depth == 0) break;
          } else {
            i++;
          }
        }
        continue;
      }
    }

    out.write(char);
    i++;
  }

  return out.toString();
}

int _skipString(String source, int start, {required bool raw}) {
  final quote = source[start];
  final triple =
      source.startsWith(quote * 3, start) && start + 2 < source.length;
  final terminator = triple ? quote * 3 : quote;

  var i = start + terminator.length;

  while (i < source.length) {
    if (!raw && source[i] == r'\') {
      i += 2;
      continue;
    }

    if (!raw && source.startsWith(r'${', i)) {
      i = _skipInterpolation(source, i + 2);
      continue;
    }

    if (source.startsWith(terminator, i)) return i + terminator.length;

    if (!triple && source[i] == '\n') return i;

    i++;
  }

  return source.length;
}

int _skipInterpolation(String source, int start) {
  var depth = 1;
  var i = start;

  while (i < source.length && depth > 0) {
    final char = source[i];

    if (char == "'" || char == '"') {
      i = _skipString(source, i, raw: false);
      continue;
    }

    if (char == '{') depth++;
    if (char == '}') depth--;
    i++;
  }

  return i;
}

String _collapseBlankLines(String source) {
  final lines = source.split('\n');
  final out = <String>[];

  for (final line in lines) {
    final blank = line.trim().isEmpty;
    if (blank && out.isNotEmpty && out.last.trim().isEmpty) continue;
    out.add(blank ? '' : line.replaceFirst(RegExp(r'\s+$'), ''));
  }

  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }

  return '${out.join('\n')}\n';
}
