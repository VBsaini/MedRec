import '../core/format.dart';

/// One of the yes/no health sections on a patient (diabetic, heart,
/// mental_health): whether it applies, a short note, and since when.
class Condition {
  const Condition({this.status = false, this.note, this.since});

  /// [noteKey] is "type" for diabetes and "details" for the others.
  factory Condition.fromJson(Object? json, String noteKey) {
    if (json is! Map) return const Condition();
    return Condition(
      status: json['status'] == true,
      note: json[noteKey] as String?,
      since: parseDate(json['since']),
    );
  }

  final bool status;
  final String? note;
  final DateTime? since;
}

/// The logged-in patient and their whole medical record, as returned by
/// `GET /api/me`.
class Patient {
  Patient(this._json);

  final Map<String, dynamic> _json;

  String get id => _json['_id'] as String;
  String get email => _json['email'] as String? ?? '';
  String get alias => _json['alias'] as String? ?? '';
  String get name => _json['name'] as String? ?? '';
  String? get cardId => _json['card_Id'] as String?;
  String? get gender => _json['gender'] as String?;
  String? get bloodGroup => _json['blood_group'] as String?;
  num? get age => _json['age'] as num?;
  num? get height => _json['height'] as num?;
  num? get weight => _json['weight'] as num?;

  Condition get diabetic => Condition.fromJson(_json['diabetic'], 'type');
  Condition get heart => Condition.fromJson(_json['heart'], 'details');
  Condition get mentalHealth =>
      Condition.fromJson(_json['mental_health'], 'details');

  /// The entries of one record list, by its key on the user document
  /// (e.g. "allergies", "emergency_contact").
  List<Map<String, dynamic>> items(String jsonKey) {
    final list = _json[jsonKey];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
