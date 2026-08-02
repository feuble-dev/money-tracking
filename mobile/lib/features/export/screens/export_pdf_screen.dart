import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';

/// Écran d'export PDF
class ExportPdfScreen extends ConsumerStatefulWidget {
  const ExportPdfScreen({super.key});

  @override
  ConsumerState<ExportPdfScreen> createState() => _ExportPdfScreenState();
}

class _ExportPdfScreenState extends ConsumerState<ExportPdfScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('fr', 'FR'),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _generateAndShare() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final startStr =
          DateTime(_startDate.year, _startDate.month, _startDate.day)
              .toIso8601String();
      final endStr =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
              .toIso8601String();

      // Transactions avec client et opérateur
      final transactions = await db.rawQuery('''
        SELECT t.*,
               o.name as operator_name,
               c.first_name as client_first_name,
               c.last_name as client_last_name,
               c.cnib_number as client_cnib_num
        FROM transactions t
        LEFT JOIN operators o ON t.operator_id = o.id
        LEFT JOIN clients c ON t.client_id = c.id
        WHERE t.status = 'completed' AND t.created_at BETWEEN ? AND ?
        ORDER BY t.created_at DESC
      ''', [startStr, endStr]);

      if (transactions.isEmpty) {
        setState(() {
          _errorMsg = 'Aucune transaction sur cette période';
          _isLoading = false;
        });
        return;
      }

      final dateFormat = DateFormat('dd/MM/yy HH:mm', 'fr_FR');
      final currFmt =
          NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);

      double totalDep = 0, totalWit = 0, totalComm = 0;
      for (final tx in transactions) {
        final amt = (tx['amount'] as num).toDouble();
        if (tx['transaction_type'] == 'deposit') {
          totalDep += amt;
        } else {
          totalWit += amt;
        }
        totalComm += (tx['commission'] as num?)?.toDouble() ?? 0;
      }

      final pdf = pw.Document();

      // Page paysage pour avoir plus de place
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MoneyTracking — Rapport de transactions',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Période: ${DateFormat('dd/MM/yyyy').format(_startDate)} — ${DateFormat('dd/MM/yyyy').format(_endDate)}  |  '
                '${transactions.length} transactions  |  '
                'Dépôts: ${currFmt.format(totalDep)} FCFA  |  '
                'Retraits: ${currFmt.format(totalWit)} FCFA  |  '
                'Commissions: ${currFmt.format(totalComm)} FCFA',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Divider(),
            ],
          ),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('MoneyTracking — FEUBLE-TechBuilder',
                  style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7)),
            ],
          ),
          build: (ctx) => [
            pw.TableHelper.fromTextArray(
              headers: [
                'Date', 'Type', 'Montant', 'Commission',
                'Client', 'Téléphone', 'CNIB', 'Naissance',
                'Opérateur', 'Source', 'ID Transaction',
              ],
              data: transactions.map((tx) {
                final date = DateTime.parse(tx['created_at'] as String);
                final clientName = tx['client_first_name'] != null
                    ? '${tx['client_first_name']} ${tx['client_last_name']}'
                    : (tx['client_name'] as String?) ?? '';
                return [
                  dateFormat.format(date),
                  tx['transaction_type'] == 'deposit' ? 'Dépôt' : 'Retrait',
                  '${currFmt.format((tx['amount'] as num).toDouble())} F',
                  '${currFmt.format((tx['commission'] as num?)?.toDouble() ?? 0)} F',
                  clientName,
                  (tx['client_phone'] as String?) ?? '',
                  (tx['client_cnib'] as String?) ??
                      (tx['client_cnib_num'] as String?) ?? '',
                  (tx['client_birth_date'] as String?) ?? '',
                  (tx['operator_name'] as String?) ?? '',
                  tx['source'] == 'sms_auto' ? 'SMS' : 'Manuel',
                  (tx['operator_transaction_id'] as String?) ?? '',
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 20,
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.0),  // Date
                1: const pw.FlexColumnWidth(1.2),  // Type
                2: const pw.FlexColumnWidth(1.5),  // Montant
                3: const pw.FlexColumnWidth(1.3),  // Commission
                4: const pw.FlexColumnWidth(2.5),  // Client
                5: const pw.FlexColumnWidth(1.8),  // Téléphone
                6: const pw.FlexColumnWidth(1.5),  // CNIB
                7: const pw.FlexColumnWidth(1.8),  // Opérateur
                8: const pw.FlexColumnWidth(1.0),  // Source
                9: const pw.FlexColumnWidth(3.0),  // ID Trans
              },
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'moneytracking_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Erreur: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(
                '${DateFormat('dd/MM/yyyy').format(_startDate)} — ${DateFormat('dd/MM/yyyy').format(_endDate)}',
              ),
              subtitle: const Text('Période du rapport'),
              trailing: const Icon(Icons.edit),
              onTap: _selectDateRange,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateAndShare,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isLoading ? 'Génération...' : 'Générer et partager'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red.shade700,
              ),
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Text(_errorMsg!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}
