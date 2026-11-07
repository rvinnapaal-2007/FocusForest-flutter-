import 'package:flutter/material.dart';

/// Lightweight Markdown renderer for AI answers.
/// Supports: headings, bullets (with nesting), numbered lists, **bold**, *italic*, `code`,
/// ``` code blocks, > quotes, --- dividers and simple | tables |.
class MarkdownLite extends StatelessWidget {
  final String data;
  final Color accent;
  const MarkdownLite({super.key, required this.data, this.accent = const Color(0xFF34D399)});

  static const TextStyle _body = TextStyle(color: Colors.white, fontSize: 14, height: 1.55);

  @override
  Widget build(BuildContext context) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    var inCode = false;
    final code = StringBuffer();
    final tableRows = <List<String>>[];

    void flushTable() {
      if (tableRows.isEmpty) return;
      widgets.add(_table(List<List<String>>.from(tableRows)));
      tableRows.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      if (line.trimLeft().startsWith('```')) {
        flushTable();
        if (inCode) {
          widgets.add(_codeBlock(code.toString().trimRight()));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.writeln(raw);
        continue;
      }

      // Table rows: | a | b |
      final t = line.trim();
      if (t.startsWith('|') && t.endsWith('|') && t.length > 2) {
        final cells = t.substring(1, t.length - 1).split('|').map((c) => c.trim()).toList();
        final isSeparator = cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
        if (!isSeparator) tableRows.add(cells);
        continue;
      } else {
        flushTable();
      }

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line.trim())) {
        widgets.add(const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)));
        continue;
      }

      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line.trim());
      if (h != null) {
        final level = h.group(1)!.length;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: level <= 3 ? 14 : 8, bottom: 4),
          child: Text.rich(
            _inline(h.group(2)!, TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: level == 1 ? 20 : level == 2 ? 18 : level == 3 ? 16.5 : 15, height: 1.3)),
          ),
        ));
        continue;
      }

      if (line.trimLeft().startsWith('>')) {
        final text = line.trimLeft().replaceFirst(RegExp(r'^>\s?'), '');
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3)), color: Colors.white.withValues(alpha: 0.04)),
          child: Text.rich(_inline(text, _body.copyWith(fontStyle: FontStyle.italic))),
        ));
        continue;
      }

      final bullet = RegExp(r'^(\s*)([-*•])\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        final depth = (bullet.group(1)!.replaceAll('\t', '    ').length ~/ 2).clamp(0, 4);
        widgets.add(_listItem(depth == 0 ? '•' : '◦', bullet.group(3)!, depth));
        continue;
      }
      final numbered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        final depth = (numbered.group(1)!.replaceAll('\t', '    ').length ~/ 2).clamp(0, 4);
        widgets.add(_listItem('${numbered.group(2)}.', numbered.group(3)!, depth));
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text.rich(_inline(line, _body)),
      ));
    }
    flushTable();
    if (inCode && code.isNotEmpty) widgets.add(_codeBlock(code.toString().trimRight()));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _listItem(String marker, String text, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: 6.0 + depth * 18, top: 2.5, bottom: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text(marker, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14, height: 1.55))),
          Expanded(child: Text.rich(_inline(text, _body))),
        ],
      ),
    );
  }

  Widget _table(List<List<String>> rows) {
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.symmetric(inside: const BorderSide(color: Colors.white12)),
            children: [
              for (var r = 0; r < rows.length; r++)
                TableRow(
                  decoration: BoxDecoration(color: r == 0 ? accent.withValues(alpha: 0.18) : Colors.transparent),
                  children: [
                    for (var c = 0; c < cols; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text.rich(_inline(c < rows[r].length ? rows[r][c] : '',
                              r == 0 ? _body.copyWith(fontWeight: FontWeight.w800, fontSize: 13) : _body.copyWith(fontSize: 13))),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF020B0A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(code, style: const TextStyle(color: Color(0xFFA7F3D0), fontFamily: 'monospace', fontSize: 12.5, height: 1.45)),
      ),
    );
  }

  TextSpan _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*\s][^*]*\*)');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tok = m.group(0)!;
      if (tok.startsWith('**')) {
        spans.add(TextSpan(text: tok.substring(2, tok.length - 2), style: const TextStyle(fontWeight: FontWeight.w800)));
      } else if (tok.startsWith('`')) {
        spans.add(TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFFDE68A), backgroundColor: Color(0x33000000)),
        ));
      } else {
        spans.add(TextSpan(text: tok.substring(1, tok.length - 1), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
