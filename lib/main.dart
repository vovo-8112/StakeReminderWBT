import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:html' as html;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stake Reminder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const StakeReminderPage(),
    );
  }
}

class StakeItem {
  final String currency;
  final double openAmount;
  final DateTime? openDate;
  final DateTime? closeDate;
  final double planPercent;
  final double earnAmount;

  StakeItem({
    required this.currency,
    required this.openAmount,
    required this.openDate,
    required this.closeDate,
    required this.planPercent,
    required this.earnAmount,
  });
}

class StakeReminderPage extends StatefulWidget {
  const StakeReminderPage({super.key});

  @override
  State<StakeReminderPage> createState() => _StakeReminderPageState();
}

class _StakeReminderPageState extends State<StakeReminderPage> {
  List<StakeItem> stakingData = [];
  bool fileLoaded = false;

  Future<void> pickFile() async {
    debugPrint('Starting file picking...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes!;
      final ext = file.extension?.toLowerCase() ?? '';

      debugPrint('File picked with extension: $ext');

      if (ext == 'csv') {
        readCsv(bytes);
      }

      setState(() {
        fileLoaded = true;
      });
    } else {
      debugPrint('No file selected.');
    }
  }

  void readCsv(Uint8List bytes) {
    debugPrint('Starting CSV parsing...');
    final csvString = String.fromCharCodes(bytes);
    final rows = CsvToListConverter().convert(csvString);

    List<StakeItem> temp = [];

    for (int i = 1; i < rows.length; i++) { // пропускаємо заголовки
      final row = rows[i];
      if (row.isEmpty) continue;

      try {
        final currency = row.length > 1 ? row[1].toString() : '';
        final openDate = row.length > 6 ? _parseDate(row[6]) : null;

        // <-- ВАЖЛИВО: planPeriod тут у хвилинах (43200 -> 30 днів)
        final planPeriodMinutes = row.length > 4 ? _toDouble(row[4]) : 0.0;

        DateTime? closeDate;
        if (openDate != null && planPeriodMinutes > 0) {
          closeDate = openDate.add(Duration(minutes: planPeriodMinutes.toInt()));
        }

        final openAmount = row.length > 5 ? _toDouble(row[5]) : 0.0;
        final planPercent = row.length > 3 ? _toDouble(row[3]) : 0.0;
        final earnAmount = row.length > 9 ? _toDouble(row[9]) : 0.0;

        temp.add(StakeItem(
          currency: currency,
          openAmount: openAmount,
          openDate: openDate,
          closeDate: closeDate,
          planPercent: planPercent,
          earnAmount: earnAmount,
        ));
      } catch (e) {
        debugPrint('Skipping row $i due to error: $e');
        continue;
      }
    }

    setState(() {
      stakingData = temp;
    });
    debugPrint('CSV parsing completed. Parsed ${temp.length} items.');
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      debugPrint('_toDouble: null value, returning 0.0');
      return 0.0;
    }
    if (value is double) {
      debugPrint('_toDouble: double value $value');
      return value;
    }
    if (value is int) {
      debugPrint('_toDouble: int value $value');
      return value.toDouble();
    }
    if (value is num) {
      debugPrint('_toDouble: num value $value');
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value) ?? 0.0;
      debugPrint('_toDouble: parsed string "$value" to $parsed');
      return parsed;
    }
    debugPrint('_toDouble: unknown type, returning 0.0');
    return 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      debugPrint('_parseDate: null or empty value, returning null');
      return null;
    }

    if (value is DateTime) {
      debugPrint('_parseDate: DateTime value $value');
      return value;
    }

    if (value is String) {
      // Заміна "UTC" на "T" і додавання "Z" наприкінці
      String formatted = value.replaceAll('UTC', 'T').trim();
      if (!formatted.endsWith('Z')) {
        formatted += 'Z';
      }
      final parsed = DateTime.tryParse(formatted);
      if (parsed != null) {
        debugPrint('_parseDate: parsed string "$value" to $parsed');
        return parsed;
      }
      debugPrint('_parseDate: failed to parse string "$value", returning null');
      return null;
    }

    if (value is num) {
      // Іноді дата може бути у вигляді Excel-числа (дні з 1899-12-30)
      final excelEpoch = DateTime(1899, 12, 30);
      final days = value.toDouble();
      final date = excelEpoch.add(Duration(days: days.floor()));
      debugPrint('_parseDate: parsed numeric excel date $value to $date');
      return date;
    }

    debugPrint('_parseDate: unknown type, returning null');
    return null;
  }

  void generateCalendar() {
    debugPrint('Generating calendar with ${stakingData.length} events...');
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Stake Reminder//EN');
    for (var item in stakingData) {
      // Пропускаємо елементи без closeDate (щоб не генерувати пусті події)
      if (item.closeDate == null) continue;
      final dtStart = _formatDateForIcs(item.closeDate);
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('SUMMARY:${item.currency} staking ends');
      buffer.writeln('DTSTART:$dtStart');
      buffer.writeln('DTEND:$dtStart');
      buffer.writeln('DESCRIPTION:Stake ends for ${item.currency}');
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    downloadFile('staking_calendar.ics', buffer.toString());
    debugPrint('Calendar generation completed.');
  }

  String _formatDateForIcs(DateTime? date) {
    if (date == null) return '';
    final utc = date.toUtc();
    return '${utc.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
  }

  void downloadFile(String fileName, String content) {
    final blob = html.Blob([content], 'text/calendar;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stake Reminder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickFile,
              child: const Text('Вибрати CSV'),
            ),
            const SizedBox(height: 16),
            if (fileLoaded)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Currency')),
                      DataColumn(label: Text('Open Amount')),
                      DataColumn(label: Text('Open Date')),
                      DataColumn(label: Text('Close Date')),
                      DataColumn(label: Text('Plan %')),
                      DataColumn(label: Text('Earn Amount')),
                    ],
                    rows: stakingData.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.currency)),
                        DataCell(Text(item.openAmount.toStringAsFixed(2))),
                        DataCell(Text(item.openDate?.toLocal().toString().split(' ').first ?? '')),
                        DataCell(Text(item.closeDate?.toLocal().toString().split(' ').first ?? '')),
                        DataCell(Text(item.planPercent.toStringAsFixed(2))),
                        DataCell(Text(item.earnAmount.toStringAsFixed(2))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fileLoaded ? generateCalendar : null,
              child: const Text('Створити календар'),
            ),
          ],
        ),
      ),
    );
  }
}