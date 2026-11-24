import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/core/format.dart';
import 'package:medrec/core/session.dart';
import 'package:medrec/features/records/record_kind.dart';
import 'package:medrec/features/reports/attachments.dart';
import 'package:medrec/models/patient.dart';
import 'package:medrec/models/report.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('adds http and strips trailing slash and /api', () {
      expect(
        normalizeBaseUrl(' 192.168.1.20:5000/ '),
        'http://192.168.1.20:5000',
      );
      expect(
        normalizeBaseUrl('http://10.0.2.2:5000/api/'),
        'http://10.0.2.2:5000',
      );
      expect(
        normalizeBaseUrl('https://medrec.example'),
        'https://medrec.example',
      );
    });
  });

  group('dates', () {
    test('a stored calendar date keeps its day regardless of time zone', () {
      final date = parseDate('2023-01-15T00:00:00.000Z');
      expect(date, DateTime(2023, 1, 15));
      expect(dateToWire(date), '2023-01-15');
      expect(formatDate(date), '15 Jan 2023');
    });

    test('missing or invalid values become null / empty', () {
      expect(parseDate(null), isNull);
      expect(parseDate('not a date'), isNull);
      expect(dateToWire(null), '');
      expect(formatDate(null), '');
    });
  });

  test('mimeTypeForName only recognises uploadable types', () {
    expect(mimeTypeForName('Scan.JPG'), 'image/jpeg');
    expect(mimeTypeForName('report.pdf'), 'application/pdf');
    expect(mimeTypeForName('photo.heic'), 'image/heic');
    expect(mimeTypeForName('notes.docx'), isNull);
    expect(mimeTypeForName('noextension'), isNull);
  });

  test('Patient reads a user document from the API', () {
    final patient = Patient({
      '_id': 'abc',
      'name': 'Vaibhav Saini',
      'email': 'v@example.com',
      'age': 30,
      'height': 170,
      'blood_group': 'O+',
      'diabetic': {
        'status': true,
        'type': 'Type 2',
        'since': '2023-01-15T00:00:00.000Z',
      },
      'heart': {'status': false, 'surgeries': [], 'medications': []},
      'allergies': [
        {
          '_id': 'a1',
          'allergens': 'Peanuts',
          'reactions': 'Hives',
          'severity': 'Severe',
        },
      ],
      'emergency_contact': [],
    });

    expect(patient.name, 'Vaibhav Saini');
    expect(patient.cardId, isNull);
    expect(patient.diabetic.status, isTrue);
    expect(patient.diabetic.note, 'Type 2');
    expect(patient.diabetic.since, DateTime(2023, 1, 15));
    expect(patient.heart.status, isFalse);
    expect(patient.mentalHealth.status, isFalse);
    expect(patient.items('allergies').single['allergens'], 'Peanuts');
    expect(patient.items('emergency_contact'), isEmpty);
    expect(patient.items('medications'), isEmpty);
  });

  test('Report reads files and falls back for unknown categories', () {
    final report = Report.fromJson({
      '_id': 'r1',
      'title': 'CBC',
      'category': 'something_new',
      'date': '2024-03-15T00:00:00.000Z',
      'files': [
        {
          '_id': 'f1',
          'originalName': 'cbc.jpg',
          'mimeType': 'image/jpeg',
          'size': 2048,
        },
        {'_id': 'f2', 'originalName': 'cbc.pdf', 'mimeType': 'application/pdf'},
      ],
    });

    expect(report.categoryLabel, 'Other');
    expect(report.date, DateTime(2024, 3, 15));
    expect(report.files[0].isImage, isTrue);
    expect(report.files[1].isPdf, isTrue);
    expect(formatFileSize(report.files[0].size), '2 KB');
  });

  test('every record kind has a unique slug and a real title field', () {
    final slugs = recordKinds.map((k) => k.slug).toSet();
    expect(slugs.length, recordKinds.length);
    for (final kind in recordKinds) {
      expect(kind.fields.map((f) => f.key), contains(kind.titleKey));
      expect(recordKindBySlug(kind.slug), same(kind));
    }
  });
}
