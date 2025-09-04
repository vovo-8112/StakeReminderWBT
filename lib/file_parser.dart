import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

class FileParser {
  /// Головний метод: повертає List<List<String>> незалежно від формату
  static Future<List<List<String>>> parseFile(Uint8List bytes, String extension) async {
    if (extension.toLowerCase() == 'csv') {
      return csvToList(bytes);
    } else if (extension.toLowerCase() == 'xlsx') {
      return excelToCsv(bytes);
    } else {
      throw UnsupportedError('Unsupported file type: $extension');
    }
  }

  /// Конвертація CSV у List<List<String>>
  static List<List<String>> csvToList(Uint8List bytes) {
    final csvString = String.fromCharCodes(bytes);
    return const CsvToListConverter().convert(csvString).map((row) => row.map((e) => e.toString()).toList()).toList();
  }

  /// Конвертація XLSX у List<List<String>> (як CSV)
  static List<List<String>> excelToCsv(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return [];

    List<List<String>> csvRows = [];
    for (var row in sheet.rows) {
      csvRows.add(row.map((cell) => cell?.value.toString() ?? '').toList());
    }
    return csvRows;
  }
}