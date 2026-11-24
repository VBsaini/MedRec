import '../core/format.dart';

/// Report categories: API value -> label. Must match the backend enum.
const reportCategories = <String, String>{
  'lab_report': 'Lab report',
  'prescription': 'Prescription',
  'scan': 'Scan or X-ray',
  'discharge_summary': 'Discharge summary',
  'other': 'Other',
};

/// A photo or PDF attached to a report, stored on the server.
class ReportFile {
  ReportFile.fromJson(Map<String, dynamic> json)
    : id = json['_id'] as String,
      name = json['originalName'] as String? ?? 'File',
      mimeType = json['mimeType'] as String? ?? '',
      size = json['size'] as int?;

  final String id;
  final String name;
  final String mimeType;
  final int? size;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
}

class Report {
  Report.fromJson(Map<String, dynamic> json)
    : id = json['_id'] as String,
      title = json['title'] as String? ?? '',
      description = json['description'] as String?,
      category = json['category'] as String? ?? 'other',
      date = parseDate(json['date']),
      files = [
        for (final f in json['files'] as List? ?? const [])
          ReportFile.fromJson(Map<String, dynamic>.from(f as Map)),
      ];

  final String id;
  final String title;
  final String? description;
  final String category;
  final DateTime? date;
  final List<ReportFile> files;

  String get categoryLabel => reportCategories[category] ?? 'Other';
}
