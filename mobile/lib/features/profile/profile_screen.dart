import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../auth/auth_controller.dart';

const _genders = ['Male', 'Female', 'Other'];
const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// Editable state for one yes/no health section.
class _ConditionForm {
  _ConditionForm(Condition condition)
    : status = condition.status,
      since = condition.since,
      note = TextEditingController(text: condition.note);

  bool status;
  DateTime? since;
  final TextEditingController note;

  /// [noteKey] is the API field the note is stored in.
  Map<String, dynamic> toJson(String noteKey) => {
    'status': status,
    // When switched off, clear the details so stale notes do not linger.
    noteKey: status ? note.text.trim() : '',
    'since': status ? dateToWire(since) : '',
  };
}

/// Basic details plus the diabetes / heart / mental-health sections.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final _ConditionForm _diabetic;
  late final _ConditionForm _heart;
  late final _ConditionForm _mental;
  String? _gender;
  String? _bloodGroup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(patientProvider);
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: _number(p.age));
    _height = TextEditingController(text: _number(p.height));
    _weight = TextEditingController(text: _number(p.weight));
    _gender = p.gender;
    _bloodGroup = p.bloodGroup;
    _diabetic = _ConditionForm(p.diabetic);
    _heart = _ConditionForm(p.heart);
    _mental = _ConditionForm(p.mentalHealth);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _age,
      _height,
      _weight,
      _diabetic.note,
      _heart.note,
      _mental.note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 170.0 -> "170", 68.5 -> "68.5", null -> "".
  static String _number(num? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? '${value.round()}' : '$value';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // Empty strings tell the server to clear a field.
      final user = await ref
          .read(apiClientProvider)
          .patch(
            '/me/profile',
            data: {
              'name': _name.text.trim(),
              'age': _age.text.trim(),
              'gender': _gender ?? '',
              'blood_group': _bloodGroup ?? '',
              'height': _height.text.trim(),
              'weight': _weight.text.trim(),
              'diabetic': _diabetic.toJson('type'),
              'heart': _heart.toJson('details'),
              'mental_health': _mental.toJson('details'),
            },
          );
      ref.read(authControllerProvider.notifier).setPatient(user);
      if (mounted) {
        showMessage(context, 'Profile saved');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _range(String? value, num max, {bool whole = false}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final n = whole ? int.tryParse(text) : num.tryParse(text);
    if (n == null || n <= 0 || n > max) return 'Enter a number up to $max';
    return null;
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        // Keep an existing value even if it is not one of the options.
        for (final option in {...options, if (value != null) value})
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: _busy ? null : (v) => setState(() => onChanged(v)),
    );
  }

  Widget _condition({
    required String title,
    required String noteLabel,
    required String noteHint,
    required _ConditionForm form,
  }) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(title),
            value: form.status,
            onChanged: _busy ? null : (v) => setState(() => form.status = v),
          ),
          if (form.status)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextFormField(
                    controller: form.note,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: noteLabel,
                      hintText: noteHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DateField(
                    label: 'Since',
                    enabled: !_busy,
                    value: form.since,
                    onChanged: (d) => setState(() => form.since = d),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile and conditions')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name *'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Age'),
                      validator: (v) => _range(v, 150, whole: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown(
                      'Gender',
                      _gender,
                      _genders,
                      (v) => _gender = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _dropdown(
                'Blood group',
                _bloodGroup,
                _bloodGroups,
                (v) => _bloodGroup = v,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _height,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: decimal,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'cm',
                      ),
                      validator: (v) => _range(v, 300),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: decimal,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        suffixText: 'kg',
                      ),
                      validator: (v) => _range(v, 500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Conditions', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _condition(
                title: 'Diabetes',
                noteLabel: 'Type',
                noteHint: 'e.g. Type 2',
                form: _diabetic,
              ),
              const SizedBox(height: 8),
              _condition(
                title: 'Heart condition',
                noteLabel: 'Details',
                noteHint: 'e.g. Hypertension',
                form: _heart,
              ),
              const SizedBox(height: 8),
              _condition(
                title: 'Mental health condition',
                noteLabel: 'Details',
                noteHint: 'e.g. Anxiety, on treatment',
                form: _mental,
              ),
              const SizedBox(height: 24),
              SubmitButton(label: 'Save', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
