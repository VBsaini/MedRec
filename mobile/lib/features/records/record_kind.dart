import 'package:flutter/material.dart';

import '../../core/format.dart';

enum FieldType { text, multiline, phone, date, choice }

/// One editable field of a record entry.
class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.options = const [],
    this.hint,
  });

  /// Field name in the API JSON.
  final String key;
  final String label;
  final FieldType type;
  final bool required;

  /// Choices for [FieldType.choice].
  final List<String> options;
  final String? hint;
}

/// Describes one list in the medical record (allergies, medications, ...):
/// where it lives in the API and which fields an entry has. The list and form
/// screens are generated from this, so adding a field is a one-line change.
class RecordKind {
  const RecordKind({
    required this.slug,
    required this.jsonKey,
    required this.title,
    required this.singular,
    required this.icon,
    required this.fields,
    required this.titleKey,
    required this.subtitle,
    required this.emptyHint,
  });

  /// URL segment: `/api/me/<slug>`.
  final String slug;

  /// Key of this list on the user document.
  final String jsonKey;
  final String title;
  final String singular;
  final IconData icon;
  final List<FieldSpec> fields;

  /// Field shown as the headline of an entry.
  final String titleKey;

  /// Secondary line for an entry in the list.
  final String Function(Map<String, dynamic> item) subtitle;
  final String emptyHint;
}

String _join(Iterable<Object?> parts) => parts
    .map((p) => p?.toString().trim() ?? '')
    .where((p) => p.isNotEmpty)
    .join(' · ');

final recordKinds = <RecordKind>[
  RecordKind(
    slug: 'allergies',
    jsonKey: 'allergies',
    title: 'Allergies',
    singular: 'allergy',
    icon: Icons.warning_amber_outlined,
    titleKey: 'allergens',
    emptyHint: 'Add food, drug or other allergies so responders see them.',
    fields: const [
      FieldSpec(
        'allergens',
        'Allergic to',
        required: true,
        hint: 'e.g. Penicillin',
      ),
      FieldSpec(
        'reactions',
        'Reaction',
        required: true,
        hint: 'e.g. Skin rash, swelling',
      ),
      FieldSpec(
        'severity',
        'Severity',
        type: FieldType.choice,
        required: true,
        options: ['Mild', 'Moderate', 'Severe'],
      ),
    ],
    subtitle: (i) => _join([i['severity'], i['reactions']]),
  ),
  RecordKind(
    slug: 'medications',
    jsonKey: 'medications',
    title: 'Medications',
    singular: 'medication',
    icon: Icons.medication_outlined,
    titleKey: 'name',
    emptyHint: 'Add the medicines you take regularly.',
    fields: const [
      FieldSpec('name', 'Medicine name', required: true),
      FieldSpec('dosage', 'Dosage', hint: 'e.g. 500mg'),
      FieldSpec('frequency', 'How often', hint: 'e.g. Twice daily'),
      FieldSpec('prescribedFor', 'Prescribed for'),
      FieldSpec('prescribedBy', 'Prescribed by'),
      FieldSpec('startDate', 'Start date', type: FieldType.date),
      FieldSpec('endDate', 'End date', type: FieldType.date),
    ],
    subtitle: (i) => _join([i['dosage'], i['frequency'], i['prescribedFor']]),
  ),
  RecordKind(
    slug: 'surgeries',
    jsonKey: 'surgeries',
    title: 'Surgeries',
    singular: 'surgery',
    icon: Icons.local_hospital_outlined,
    titleKey: 'surgeryType',
    emptyHint: 'Add past operations and procedures.',
    fields: const [
      FieldSpec(
        'surgeryType',
        'Surgery or procedure',
        required: true,
        hint: 'e.g. Appendectomy',
      ),
      FieldSpec('surgeryDate', 'Date', type: FieldType.date, required: true),
      FieldSpec('hospitalName', 'Hospital'),
      FieldSpec('doctorName', 'Doctor'),
      FieldSpec('details', 'Details', type: FieldType.multiline),
    ],
    subtitle:
        (i) =>
            _join([formatDate(parseDate(i['surgeryDate'])), i['hospitalName']]),
  ),
  RecordKind(
    slug: 'medical-history',
    jsonKey: 'medical_history',
    title: 'Medical history',
    singular: 'history entry',
    icon: Icons.history_edu_outlined,
    titleKey: 'past_illnesses',
    emptyHint: 'Add past illnesses and long-term conditions.',
    fields: const [
      FieldSpec(
        'past_illnesses',
        'Illness or condition',
        type: FieldType.multiline,
        required: true,
        hint: 'e.g. Childhood asthma',
      ),
    ],
    subtitle: (i) => '',
  ),
  RecordKind(
    slug: 'family-history',
    jsonKey: 'family_history',
    title: 'Family history',
    singular: 'family member',
    icon: Icons.family_restroom_outlined,
    titleKey: 'relationship',
    emptyHint: 'Add conditions that run in your family.',
    fields: const [
      FieldSpec(
        'relationship',
        'Relative',
        required: true,
        hint: 'e.g. Father',
      ),
      FieldSpec(
        'conditions',
        'Conditions',
        type: FieldType.multiline,
        required: true,
        hint: 'e.g. Type 2 diabetes, hypertension',
      ),
    ],
    subtitle: (i) => _join([i['conditions']]),
  ),
  RecordKind(
    slug: 'emergency-contacts',
    jsonKey: 'emergency_contact',
    title: 'Emergency contacts',
    singular: 'contact',
    icon: Icons.contact_phone_outlined,
    titleKey: 'name',
    emptyHint: 'Add people to call in an emergency.',
    fields: const [
      FieldSpec('name', 'Name', required: true),
      FieldSpec(
        'phone_number',
        'Phone number',
        type: FieldType.phone,
        required: true,
      ),
      FieldSpec('relationship', 'Relationship', hint: 'e.g. Mother'),
    ],
    subtitle: (i) => _join([i['relationship'], i['phone_number']]),
  ),
];

RecordKind recordKindBySlug(String slug) =>
    recordKinds.firstWhere((kind) => kind.slug == slug);
