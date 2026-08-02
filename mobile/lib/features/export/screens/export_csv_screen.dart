import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_helper.dart';

/// Écran d'export CSV avec toutes les colonnes
class ExportCsvScreen extends ConsumerStatefulWidget {
  const ExportCsvScreen({super.key});

  @override
  ConsumerState<ExportCsvScreen> createState() => _ExportCsvScreenState();
}

class _ExportCsvScreenState extends ConsumerState<ExportCsvScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  String _exportType = 'transactions'; // 'transactions' | 'clients'

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

  Future<void> _exportCsv() async {
    setState(() => _isLoading = true);

    try {
      if (_exportType == 'transactions') {
        await _exportTransactions();
      } else {
        await _exportClients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final startStr =
        DateTime(_startDate.year, _startDate.month, _startDate.day)
            .toIso8601String();
    final endStr =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
            .toIso8601String();

    final transactions = await db.rawQuery('''
      SELECT t.*,
             o.name as operator_name,
             c.first_name as client_first_name,
             c.last_name as client_last_name,
             c.cnib_number as client_cnib_num,
             c.birth_date as client_birth
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      LEFT JOIN clients c ON t.client_id = c.id
      WHERE t.status = 'completed' AND t.created_at BETWEEN ? AND ?
      ORDER BY t.created_at DESC
    ''', [startStr, endStr]);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

    final rows = <List<dynamic>>[
      [
        'Date', 'Type', 'Montant (FCFA)', 'Commission (FCFA)',
        'Nom client', 'Prénom client', 'Téléphone', 'CNIB client',
        'Date naissance', 'CNIB transaction', 'Date naissance transaction',
        'Opérateur', 'Source', 'ID Transaction opérateur', 'Référence',
        'Status',
      ],
      ...transactions.map((tx) {
        final date = DateTime.parse(tx['created_at'] as String);
        return [
          dateFormat.format(date),
          tx['transaction_type'] == 'deposit' ? 'Dépôt' : 'Retrait',
          (tx['amount'] as num).toDouble(),
          (tx['commission'] as num?)?.toDouble() ?? 0,
          (tx['client_last_name'] as String?) ??
              (tx['client_name'] as String?) ?? '',
          (tx['client_first_name'] as String?) ?? '',
          (tx['client_phone'] as String?) ?? '',
          (tx['client_cnib_num'] as String?) ?? '',
          (tx['client_birth'] as String?) ?? '',
          (tx['client_cnib'] as String?) ?? '',
          (tx['client_birth_date'] as String?) ?? '',
          (tx['operator_name'] as String?) ?? '',
          tx['source'] == 'sms_auto' ? 'SMS' : 'Manuel',
          (tx['operator_transaction_id'] as String?) ?? '',
          (tx['operator_reference'] as String?) ?? '',
          (tx['status'] as String?) ?? '',
        ];
      }),
    ];

    await _shareFile(rows, 'transactions');
  }

  Future<void> _exportClients() async {
    final db = await DatabaseHelper.instance.database;

    final clients = await db.rawQuery('''
      SELECT c.*, o.name as operator_name,
             COUNT(t.id) as tx_count,
             COALESCE(SUM(CASE WHEN t.transaction_type='deposit' THEN t.amount ELSE 0 END), 0) as total_deposits,
             COALESCE(SUM(CASE WHEN t.transaction_type='withdrawal' THEN t.amount ELSE 0 END), 0) as total_withdrawals
      FROM clients c
      LEFT JOIN operators o ON c.operator_id = o.id
      LEFT JOIN transactions t ON t.client_id = c.id AND t.status = 'completed'
      GROUP BY c.id
      ORDER BY c.first_name ASC
    ''');

    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    final rows = <List<dynamic>>[
      [
        'Nom', 'Prénom', 'Téléphone', 'CNIB',
        'Date naissance', 'Opérateur',
        'Nb transactions', 'Total dépôts (FCFA)', 'Total retraits (FCFA)',
        'Date création',
      ],
      ...clients.map((c) {
        final createdAt = DateTime.parse(c['created_at'] as String);
        return [
          c['last_name'] as String,
          c['first_name'] as String,
          c['phone_number'] as String,
          (c['cnib_number'] as String?) ?? '',
          (c['birth_date'] as String?) ?? '',
          (c['operator_name'] as String?) ?? '',
          (c['tx_count'] as num).toInt(),
          (c['total_deposits'] as num).toDouble(),
          (c['total_withdrawals'] as num).toDouble(),
          dateFormat.format(createdAt),
        ];
      }),
    ];

    await _shareFile(rows, 'clients');
  }

  Future<void> _shareFile(List<List<dynamic>> rows, String prefix) async {
    final csvString = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final fileName =
        'moneytracking_${prefix}_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Export MoneyTracking — $prefix',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export CSV / Excel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Choix type d'export
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type d\'export',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'transactions',
                        label: Text('Transactions'),
                        icon: Icon(Icons.receipt_long),
                      ),
                      ButtonSegment(
                        value: 'clients',
                        label: Text('Clients'),
                        icon: Icon(Icons.people),
                      ),
                    ],
                    selected: {_exportType},
                    onSelectionChanged: (v) =>
                        setState(() => _exportType = v.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Période
          if (_exportType == 'transactions')
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(
                  '${DateFormat('dd/MM/yyyy').format(_startDate)} — ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                ),
                subtitle: const Text('Période de l\'export'),
                trailing: const Icon(Icons.edit),
                onTap: _selectDateRange,
              ),
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _exportCsv,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_chart),
              label: Text(_isLoading ? 'Export...' : 'Exporter et partager'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Le fichier CSV est compatible avec Excel et LibreOffice Calc.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
