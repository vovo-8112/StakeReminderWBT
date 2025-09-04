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
  final String planName;
  final String platform;

  StakeItem({
    required this.currency,
    required this.openAmount,
    required this.openDate,
    required this.closeDate,
    required this.planPercent,
    required this.earnAmount,
    required this.planName,
    required this.platform,
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes!;
      final ext = file.extension?.toLowerCase() ?? '';

      if (ext == 'csv') {
        readCsv(bytes);
      }

      setState(() {
        fileLoaded = true;
      });
    }
  }

  void readCsv(Uint8List bytes) {
    final csvString = String.fromCharCodes(bytes);
    final rows = CsvToListConverter().convert(csvString);

    List<StakeItem> temp = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final currency = row.length > 1 ? row[1].toString() : '';
      final openDate = row.length > 6 ? _parseDate(row[6]) : null;
      final planPeriodMinutes = row.length > 4 ? _toDouble(row[4]) : 0.0;
      final planName = _planName(planPeriodMinutes);

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
        planName: planName,
        platform: 'WhiteBIT',
      ));
    }

    setState(() {
      stakingData = temp;
    });
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      String formatted = value.replaceAll('UTC', 'T').trim();
      if (!formatted.endsWith('Z')) formatted += 'Z';
      return DateTime.tryParse(formatted);
    }
    if (value is num) {
      final excelEpoch = DateTime(1899, 12, 30);
      return excelEpoch.add(Duration(days: value.floor()));
    }
    return null;
  }

  String _planName(double minutes) {
    final days = minutes / 1440;
    if (days >= 360) return 'Year';
    if (days >= 180) return 'Half Year';
    if (days >= 90) return '3 Months';
    if (days >= 30) return 'Month';
    return '${days.round()} Days';
  }

  void generateCalendar() {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Stake Reminder//EN');

    for (var item in stakingData) {
      if (item.closeDate == null) continue;
      final dtStart = _formatDateForIcs(item.closeDate);
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('SUMMARY:${item.platform} - ${item.planName} staking ends');
      buffer.writeln('DTSTART:$dtStart');
      buffer.writeln('DTEND:$dtStart');
      buffer.writeln('DESCRIPTION:Stake ends for ${item.currency}');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    downloadFile('staking_calendar.ics', buffer.toString());
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

  // ----------------- Google Calendar -----------------
  void openGoogleCalendar(StakeItem item) {
    if (item.closeDate == null) return;

    final start = _formatDateForGCal(item.closeDate!);
    final end = _formatDateForGCal(item.closeDate!.add(const Duration(hours: 1)));
    final url =
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=${Uri.encodeComponent(item.platform + ' - ' + item.planName)}&dates=$start/$end&details=${Uri.encodeComponent('Stake ends for ${item.currency}')}';

    html.window.open(url, '_blank');
  }

  String _formatDateForGCal(DateTime date) {
    final utc = date.toUtc();
    return '${utc.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
  }
  // ---------------------------------------------------

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
                      DataColumn(label: Text('Plan Name')),
                      DataColumn(label: Text('Platform')),
                      DataColumn(label: Text('Google Calendar')),
                    ],
                    rows: stakingData.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.currency)),
                        DataCell(Text(item.openAmount.toStringAsFixed(2))),
                        DataCell(Text(item.openDate?.toLocal().toString().split(' ').first ?? '')),
                        DataCell(Text(item.closeDate?.toLocal().toString().split(' ').first ?? '')),
                        DataCell(Text(item.planPercent.toStringAsFixed(2))),
                        DataCell(Text(item.earnAmount.toStringAsFixed(2))),
                        DataCell(Text(item.planName)),
                        DataCell(Text(item.platform)),
                        DataCell(
                          ElevatedButton(
                            onPressed: () => openGoogleCalendar(item),
                            child: const Text('Add to Google Calendar'),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fileLoaded ? generateCalendar : null,
              child: const Text('Створити календар (.ics)'),
            ),
          ],
        ),
      ),
    );
  }
}