import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'record_kind.dart';

/// Add or edit one entry of a record kind. Pass [item] to edit.
class RecordFormScreen extends ConsumerStatefulWidget {
  const RecordFormScreen({super.key, required this.kind, this.item});

  final RecordKind kind;
  final Map<String, dynamic>? item;

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  final _dates = <String, DateTime?>{};
  final _choices = <String, String?>{};
  bool _busy = false;

  RecordKind get _kind => widget.kind;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? const <String, dynamic>{};
    for (final field in _kind.fields) {
      final value = item[field.key];
      switch (field.type) {
        case FieldType.date:
          _dates[field.key] = parseDate(value);
        case FieldType.choice:
          // Keep an existing value even if it is not one of the options.
          _choices[field.key] = value as String?;
        default:
          _text[field.key] = TextEditingController(text: value as String?);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Runs an API call, then reloads the record and closes the form.
  Future<void> _run(Future<void> Function(ApiClient api) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(apiClientProvider));
      await ref.read(authControllerProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Empty strings tell the server to clear a field.
    final body = <String, dynamic>{
      for (final field in _kind.fields)
        field.key: switch (field.type) {
          FieldType.date => dateToWire(_dates[field.key]),
          FieldType.choice => _choices[field.key] ?? '',
          _ => _text[field.key]!.text.trim(),
        },
    };
    final path = '/me/${_kind.slug}';
    await _run(
      (api) =>
          _editing
              ? api.put('$path/${widget.item!['_id']}', data: body)
              : api.post(path, data: body),
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this ${_kind.singular}?',
      message: 'It will be removed from your record.',
    );
    if (!ok) return;
    await _run((api) => api.delete('/me/${_kind.slug}/${widget.item!['_id']}'));
  }

  Widget _buildField(FieldSpec field) {
    final label = field.required ? '${field.label} *' : field.label;
    switch (field.type) {
      case FieldType.date:
        return DateField(
          label: field.label,
          required: field.required,
          enabled: !_busy,
          value: _dates[field.key],
          onChanged: (date) => setState(() => _dates[field.key] = date),
        );
      case FieldType.choice:
        final current = _choices[field.key];
        return DropdownButtonFormField<String>(
          value: current,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final option in {
              ...field.options,
              if (current != null) current,
            })
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged:
              _busy
                  ? null
                  : (value) => setState(() => _choices[field.key] = value),
          validator:
              (value) => field.required && value == null ? 'Required' : null,
        );
      default:
        final multiline = field.type == FieldType.multiline;
        return TextFormField(
          controller: _text[field.key],
          enabled: !_busy,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 6 : 1,
          keyboardType: switch (field.type) {
            FieldType.phone => TextInputType.phone,
            FieldType.multiline => TextInputType.multiline,
            _ => TextInputType.text,
          },
          textCapitalization:
              field.type == FieldType.phone
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
          textInputAction:
              multiline ? TextInputAction.newline : TextInputAction.next,
          decoration: InputDecoration(
            labelText: label,
            hintText: field.hint,
            alignLabelWithHint: multiline,
          ),
          validator:
              (value) =>
                  field.required && (value ?? '').trim().isEmpty
                      ? 'Required'
                      : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_editing ? 'Edit' : 'Add'} ${_kind.singular}'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final field in _kind.fields) ...[
                _buildField(field),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              SubmitButton(label: 'Save', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
