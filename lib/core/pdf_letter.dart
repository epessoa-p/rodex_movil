import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';

/// Piezas comunes de los documentos en **tamaño carta** (recibo de venta y
/// orden de trabajo): cabecera con logo y datos de la empresa, bloques de
/// información, tablas de ítems, totales y pie. El color de acento es el
/// color primario de la empresa (o el rojo Rodex si no definió uno).
class LetterDoc {
  LetterDoc({required this.company, this.logo})
    : accent = _accentFrom(company?.themePrimary);

  final Company? company;
  final Uint8List? logo;
  final PdfColor accent;

  static const _ink = PdfColor.fromInt(0xFF1F2937);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFE5E7EB);
  static const _soft = PdfColor.fromInt(0xFFF3F4F6);
  static const _red = PdfColor.fromInt(0xFFDC2626);
  static const _green = PdfColor.fromInt(0xFF15803D);

  static PdfColor _accentFrom(String? hex) {
    if (hex != null && RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return PdfColor.fromInt(
        int.parse('FF${hex.replaceFirst('#', '')}', radix: 16),
      );
    }
    return const PdfColor.fromInt(0xFFE63946);
  }

  pw.TextStyle get _h1 =>
      pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink);
  pw.TextStyle get _label => const pw.TextStyle(fontSize: 8, color: _muted);
  pw.TextStyle get _body => const pw.TextStyle(fontSize: 9.5, color: _ink);
  pw.TextStyle get _bodyBold =>
      pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink);

  /// Documento carta con márgenes y pie de página numerado.
  pw.Document document(List<pw.Widget> Function(pw.Context) build) {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(company?.name ?? '', style: _label),
              pw.Text(
                'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: _label,
              ),
            ],
          ),
        ),
        build: build,
      ),
    );
    return doc;
  }

  /// Cabecera: logo + empresa a la izquierda; título, código y fecha a la
  /// derecha; barra de color debajo.
  pw.Widget header({
    required String title,
    required String code,
    String? date,
    String? subtitle,
  }) {
    final c = company;
    final contact = [
      if (c?.address != null && c!.address!.trim().isNotEmpty)
        c.address!.trim(),
      if (c?.phone != null && c!.phone!.trim().isNotEmpty)
        'Tel. ${c.phone!.trim()}',
    ].join(' · ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null && logo!.isNotEmpty)
              pw.Container(
                height: 52,
                width: 110,
                margin: const pw.EdgeInsets.only(right: 12),
                alignment: pw.Alignment.centerLeft,
                child: pw.Image(pw.MemoryImage(logo!), fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(c?.name ?? '', style: _h1),
                  if (contact.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(contact, style: _label),
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                    letterSpacing: 1,
                  ),
                ),
                pw.Text(
                  code,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (date != null) pw.Text(date, style: _label),
                if (subtitle != null) pw.Text(subtitle, style: _label),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 3, color: accent),
        pw.SizedBox(height: 14),
      ],
    );
  }

  /// Bloque "etiqueta / valor" para las tarjetas de información.
  pw.Widget field(String label, String? value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: _label),
        pw.Text(
          // Helvetica no tiene "—" (Unicode): usar guion simple.
          (value == null || value.trim().isEmpty) ? '-' : value,
          style: _body,
        ),
      ],
    ),
  );

  /// Tarjeta con fondo suave y título (varias por fila con [cards]).
  pw.Widget card(String title, List<pw.Widget> children) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _soft,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  pw.Widget cards(List<pw.Widget> items) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 10),
        pw.Expanded(child: items[i]),
      ],
    ],
  );

  pw.Widget sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    ),
  );

  /// Tabla de ítems: cabecera con el color de acento, filas alternadas.
  /// [rows] son celdas ya formateadas; [numeric] marca columnas alineadas
  /// a la derecha; [widths] son proporciones por columna.
  pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widths,
    Set<int> numeric = const {},
  }) {
    final colWidths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < widths.length; i++) i: pw.FlexColumnWidth(widths[i]),
    };
    pw.Alignment align(int i) => numeric.contains(i)
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft;

    return pw.Table(
      columnWidths: colWidths,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [
            for (var i = 0; i < headers.length; i++)
              pw.Container(
                alignment: align(i),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                child: pw.Text(
                  headers[i],
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r.isOdd ? _soft : PdfColors.white,
            ),
            children: [
              for (var i = 0; i < rows[r].length; i++)
                pw.Container(
                  alignment: align(i),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: pw.Text(rows[r][i], style: _body),
                ),
            ],
          ),
      ],
    );
  }

  /// Caja de totales alineada a la derecha. Cada fila: (etiqueta, valor,
  /// opciones). [emphasis] pinta la fila con el color de acento.
  pw.Widget totals(List<TotalLine> lines) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Container(
      width: 230,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          for (final l in lines)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: l.emphasis
                  ? pw.BoxDecoration(
                      color: accent,
                      borderRadius: pw.BorderRadius.circular(3),
                    )
                  : null,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    l.label,
                    style: l.emphasis
                        ? pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          )
                        : _body,
                  ),
                  pw.Text(
                    l.value,
                    style: l.emphasis
                        ? pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          )
                        : pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: l.danger
                                ? _red
                                : (l.success ? _green : _ink),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  /// Etiqueta de estado (p. ej. "Pagada", "Pendiente").
  pw.Widget badge(String text, {bool ok = false, bool warn = false}) {
    final color = ok ? _green : (warn ? _red : _muted);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  pw.Widget note(String text) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: accent, width: 2)),
      color: _soft,
    ),
    child: pw.Text(text, style: _body),
  );

  pw.Widget thanks(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 22),
    child: pw.Center(
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: _muted)),
    ),
  );

  pw.Widget signature(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 34),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        for (final l in [label, 'Por ${company?.name ?? 'la empresa'}'])
          pw.Column(
            children: [
              pw.Container(width: 180, height: 0.8, color: _muted),
              pw.SizedBox(height: 3),
              pw.Text(l, style: _label),
            ],
          ),
      ],
    ),
  );

  pw.TextStyle get bold => _bodyBold;
}

class TotalLine {
  const TotalLine(
    this.label,
    this.value, {
    this.emphasis = false,
    this.danger = false,
    this.success = false,
  });
  final String label;
  final String value;
  final bool emphasis;
  final bool danger;
  final bool success;
}
