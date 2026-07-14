import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/dashboard_report_data.dart';

class DashboardReportService {
  static const int _topItemLimit = 10;

  Future<Uint8List> build(DashboardReportData data) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final topYears = data.publicationsByYear.entries.toList()
      ..sort((a, b) {
        final countComparison = b.value.compareTo(a.value);
        if (countComparison != 0) return countComparison;
        return b.key.compareTo(a.key);
      });
    final topJournals = data.journals.toList()
      ..sort((a, b) => b.worksCount.compareTo(a.worksCount));
    final topPublications = data.publications.toList()
      ..sort((a, b) => b.citationCount.compareTo(a.citationCount));
    final reportJournals = topJournals.take(_topItemLimit).toList();
    final reportPublications = topPublications.take(_topItemLimit).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.indigo300),
            ),
          ),
          child: pw.Text(
            'Journal Trend Analyzer',
            style: pw.TextStyle(
              color: PdfColors.indigo700,
              fontWeight: pw.FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 18),
          pw.Text(
            'Dashboard Analytics Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Research topic: ${data.topic}'),
          pw.Text('Data source: OpenAlex'),
          pw.Text('Generated: ${_formatDateTime(DateTime.now().toLocal())}'),
          pw.SizedBox(height: 20),
          _sectionTitle('Overview'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric(
                'Total publications',
                _formatInteger(data.totalPublications),
              ),
              _metric(
                'Average citations',
                data.averageCitations?.toStringAsFixed(1) ?? '-',
              ),
              _metric(
                'Most active year',
                data.mostActiveYear?.toString() ?? '-',
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Highlight', 'Value'],
            data: [
              ['Top journal', data.topJournal ?? '-'],
              ['Top author', data.topAuthor ?? '-'],
              [
                'Most influential publication',
                data.mostInfluentialPublication?.title ?? '-',
              ],
            ],
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.indigo100,
            ),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerAlignments: const {0: pw.Alignment.centerLeft},
            columnWidths: const {
              0: pw.FixedColumnWidth(135),
              1: pw.FlexColumnWidth(),
            },
            cellPadding: const pw.EdgeInsets.all(6),
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Top $_topItemLimit publication years'),
          if (topYears.isEmpty)
            pw.Text('No trend data available.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Rank', 'Year', 'Publications'],
              data: [
                for (var i = 0; i < topYears.take(_topItemLimit).length; i++)
                  [
                    '${i + 1}',
                    '${topYears[i].key}',
                    _formatInteger(topYears[i].value),
                  ],
              ],
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.indigo100,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              columnWidths: const {
                0: pw.FixedColumnWidth(45),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(95),
              },
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          pw.SizedBox(height: 20),
          if (reportJournals.isEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('Top $_topItemLimit journals'),
                pw.Text('No journal data available.'),
              ],
            )
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('Top $_topItemLimit journals'),
                pw.TableHelper.fromTextArray(
                  headers: const ['Rank', 'Journal', 'Publications'],
                  data: [
                    for (var i = 0; i < reportJournals.length; i++)
                      [
                        '${i + 1}',
                        reportJournals[i].name,
                        _formatInteger(reportJournals[i].worksCount),
                      ],
                  ],
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.indigo100,
                  ),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(45),
                    1: pw.FlexColumnWidth(),
                    2: pw.FixedColumnWidth(95),
                  },
                  cellPadding: const pw.EdgeInsets.all(5),
                ),
              ],
            ),
          pw.SizedBox(height: 20),
          _sectionTitle('Top $_topItemLimit most cited publications'),
          if (reportPublications.isEmpty)
            pw.Text('No publication data available.')
          else
            ...reportPublications.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final publication = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$rank. ${publication.title}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${publication.year ?? '-'} | '
                      '${_formatInteger(publication.citationCount)} citations | '
                      '${publication.journalName}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );

    return document.save();
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String _formatInteger(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return negative ? '-$formatted' : formatted;
  }

  pw.Widget _sectionTitle(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 16,
          color: PdfColors.indigo700,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _metric(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}
