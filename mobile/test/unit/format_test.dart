import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/core/format.dart';
import 'package:medrec/features/records/record_kind.dart';

void main() {
  test('formatFileSize picks a readable unit', () {
    expect(formatFileSize(null), '');
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(1023), '1023 B');
    expect(formatFileSize(1024), '1 KB');
    expect(formatFileSize(350 * 1024), '350 KB');
    expect(formatFileSize(5 * 1024 * 1024 + 300 * 1024), '5.3 MB');
  });

  test('a date late in the UTC day does not move to another day', () {
    // Stored as UTC; read as the UTC calendar day in every time zone.
    expect(parseDate('2024-03-15T23:30:00.000Z'), DateTime(2024, 3, 15));
    expect(parseDate('2024-03-15T00:00:00.000+05:30'), DateTime(2024, 3, 14));
    expect(parseDate(''), isNull);
    expect(parseDate(20240315), isNull);
  });

  test('formatTimestamp shows a point in time in local time', () {
    final value = DateTime(2026, 11, 24, 14, 5).toUtc().toIso8601String();
    expect(formatTimestamp(value), '24 Nov 2026, 2:05 PM');
    expect(formatTimestamp(null), '');
    expect(formatTimestamp('garbage'), '');
  });

  group('record list subtitles', () {
    String subtitle(String slug, Map<String, dynamic> item) =>
        recordKindBySlug(slug).subtitle(item);

    test('join the filled-in fields and skip empty ones', () {
      expect(
        subtitle('allergies', {'severity': 'Severe', 'reactions': ' Hives '}),
        'Severe · Hives',
      );
      expect(
        subtitle('medications', {'dosage': '500mg', 'frequency': '', 'prescribedFor': null}),
        '500mg',
      );
      expect(
        subtitle('emergency-contacts', {'relationship': 'Mother', 'phone_number': '98765'}),
        'Mother · 98765',
      );
      expect(subtitle('medical-history', {'past_illnesses': 'Asthma'}), '');
    });

    test('show surgery dates as calendar dates', () {
      expect(
        subtitle('surgeries', {
          'surgeryDate': '2021-06-30T00:00:00.000Z',
          'hospitalName': 'AIIMS',
        }),
        '30 Jun 2021 · AIIMS',
      );
    });
  });

  test("every entry's headline field is required", () {
    // So a saved entry always has something to show in the list.
    for (final kind in recordKinds) {
      final headline = kind.fields.firstWhere((f) => f.key == kind.titleKey);
      expect(headline.required, isTrue, reason: kind.slug);
    }
  });

  test('choice fields list their options', () {
    for (final kind in recordKinds) {
      for (final field in kind.fields.where((f) => f.type == FieldType.choice)) {
        expect(field.options, isNotEmpty, reason: '${kind.slug}.${field.key}');
      }
    }
  });
}
