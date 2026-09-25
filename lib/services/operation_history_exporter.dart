import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/operation_record.dart';
import '../models/purchase_request.dart';

/// Totales del historial: solo cuentan los tratos confirmados.
class OperationHistorySummary {
  const OperationHistorySummary({
    required this.operations,
    required this.confirmed,
    required this.confirmedVolumeMt,
    required this.confirmedValueUsd,
  });

  factory OperationHistorySummary.from(List<OperationRecord> records) {
    final confirmed =
        records.where((r) => r.status == NegotiationStatus.confirmed).toList();
    return OperationHistorySummary(
      operations: records.length,
      confirmed: confirmed.length,
      confirmedVolumeMt: confirmed.fold(0, (sum, r) => sum + r.volumeMt),
      confirmedValueUsd: confirmed.fold(0, (sum, r) => sum + r.totalUsd),
    );
  }

  final int operations;
  final int confirmed;
  final double confirmedVolumeMt;
  final double confirmedValueUsd;
}

/// REQ-30: exporta el historial de operaciones (REQ-19) a CSV o PDF.
///
/// Devuelve los bytes del archivo; guardarlo o compartirlo es trabajo de la UI
/// (ej. paquetes `share_plus` / `file_saver`). Uso:
/// ```dart
/// final records = await offerRepository.fetchOperationHistory();
/// const exporter = OperationHistoryExporter();
/// final csv = exporter.toCsv(records);
/// final pdf = await exporter.toPdf(records, userName: user.name);
/// final name = exporter.fileName('pdf');
/// ```
class OperationHistoryExporter {
  const OperationHistoryExporter();

  static const _csvHeaders = [
    'Fecha de cierre',
    'Estado',
    'Mi rol',
    'Producto',
    'Variedad',
    'Origen',
    'Destino',
    'Contraparte',
    'Empresa contraparte',
    'Precio (USD/MT)',
    'Volumen (MT)',
    'Total (USD)',
    'Rondas',
    'Motivo de cierre',
  ];

  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final _dayFmt = DateFormat('yyyy-MM-dd');
  static final _moneyFmt = NumberFormat('#,##0.00', 'es');

  /// Nombre sugerido: `historial_agrotrade_2026-09-26.csv`.
  String fileName(String extension, {DateTime? now}) =>
      'historial_agrotrade_${_dayFmt.format(now ?? DateTime.now())}.$extension';

  /// CSV para Excel en español: separador `;`, coma decimal, UTF-8 con BOM
  /// (para que las tildes se vean bien) y saltos de línea CRLF.
  Uint8List toCsv(List<OperationRecord> records) {
    final buffer = StringBuffer()..write(_csvHeaders.map(_csvField).join(';'));
    for (final r in records) {
      buffer
        ..write('\r\n')
        ..write([
          _dateFmt.format(r.closedAt.toLocal()),
          r.statusLabel,
          r.myRole,
          r.cropLabel,
          r.variety,
          r.originRegion,
          r.destinationCountry,
          r.counterpartyName,
          r.counterpartyCompany ?? '',
          _csvNumber(r.pricePerMt),
          _csvNumber(r.volumeMt),
          _csvNumber(r.totalUsd),
          '${r.roundCount}',
          r.closeReason ?? '',
        ].map(_csvField).join(';'));
    }
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
  }

  static String _csvNumber(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

  static String _csvField(String value) {
    if (value.contains(RegExp('[;"\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Reporte PDF horizontal con encabezado, tabla de operaciones y totales.
  Future<Uint8List> toPdf(
    List<OperationRecord> records, {
    required String userName,
    DateTime? from,
    DateTime? to,
    DateTime? generatedAt,
  }) {
    final summary = OperationHistorySummary.from(records);
    final range = (from == null && to == null)
        ? 'Todas las fechas'
        : '${from == null ? 'inicio' : _dayFmt.format(from)} a ${to == null ? 'hoy' : _dayFmt.format(to)}';

    final doc = pw.Document(title: 'Historial de operaciones', author: 'AgroTrade Direct');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('AgroTrade Direct - Historial de operaciones',
                style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(_pdfText(
                'Usuario: $userName   |   Periodo: $range   |   Generado: ${_dateFmt.format(generatedAt ?? DateTime.now())}'),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (context) => [
          if (records.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Text('No hay operaciones cerradas en este periodo.'),
            )
          else
            pw.TableHelper.fromTextArray(
              headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
              },
              headers: const [
                'Cierre', 'Estado', 'Rol', 'Producto', 'Variedad', 'Destino',
                'Contraparte', 'USD/MT', 'MT', 'Total USD', 'Motivo',
              ],
              data: [
                for (final r in records)
                  [
                    _dateFmt.format(r.closedAt.toLocal()),
                    r.statusLabel,
                    r.myRole,
                    r.cropLabel,
                    r.variety,
                    r.destinationCountry,
                    r.counterpartyName,
                    _moneyFmt.format(r.pricePerMt),
                    _moneyFmt.format(r.volumeMt),
                    _moneyFmt.format(r.totalUsd),
                    r.closeReason ?? '',
                  ].map(_pdfText).toList(),
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Operaciones: ${summary.operations}   |   Confirmadas: ${summary.confirmed}   |   '
            'Volumen confirmado: ${_moneyFmt.format(summary.confirmedVolumeMt)} MT   |   '
            'Valor confirmado: USD ${_moneyFmt.format(summary.confirmedValueUsd)}',
            style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Las fuentes estándar del PDF solo cubren Latin-1 (tildes y ñ sí);
  /// otros caracteres, como la raya "—" de las variedades, se reemplazan.
  static String _pdfText(String value) {
    final replaced = value
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'");
    return String.fromCharCodes(
        replaced.runes.map((c) => c <= 0xFF ? c : 0x3F /* ? */));
  }
}
