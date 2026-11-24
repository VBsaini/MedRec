import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../models/report.dart';
import 'attachments.dart';
import 'reports_controller.dart';

/// Create a report and upload its files, or (with [report]) edit the details
/// of an existing one. Files of an existing report are managed on its detail
/// screen.
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key, this.report});

  final Report? report;

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _category;
  late DateTime? _date;
  final _files = <Attachment>[];
  bool _busy = false;

  /// Upload progress 0..1 while files are being sent.
  double? _progress;

  bool get _editing => widget.report != null;

  @override
  void initState() {
    super.initState();
    final report = widget.report;
    _title = TextEditingController(text: report?.title);
    _description = TextEditingController(text: report?.description);
    _category =
        reportCategories.containsKey(report?.category)
            ? report!.category
            : 'lab_report';
    final today = DateTime.now();
    _date = report?.date ?? DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final picked = await pickAttachments(
      context,
      remaining: maxFilesPerReport - _files.length,
    );
    if (picked.isNotEmpty && mounted) setState(() => _files.addAll(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_editing && _files.isEmpty) {
      showMessage(context, 'Add at least one photo or PDF.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = _editing ? null : 0;
    });
    final reports = ref.read(reportsProvider.notifier);
    try {
      if (_editing) {
        await reports.updateDetails(
          widget.report!.id,
          title: _title.text.trim(),
          category: _category,
          date: _date,
          description: _description.text.trim(),
        );
      } else {
        await reports.create(
          title: _title.text.trim(),
          category: _category,
          date: _date,
          description: _description.text.trim(),
          files: _files,
          onProgress: (fraction) {
            if (mounted) setState(() => _progress = fraction);
          },
        );
      }
      if (mounted) {
        showMessage(context, _editing ? 'Report updated' : 'Report uploaded');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      // Everything the user entered and picked is kept so they can retry.
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;

    return PopScope(
      // Leaving mid-upload would lose track of it; make the user wait.
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit report' : 'Add report')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g. Blood test, March 2024',
                    counterText: '',
                  ),
                  validator:
                      (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final entry in reportCategories.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged:
                      _busy ? null : (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 16),
                DateField(
                  label: 'Report date',
                  enabled: !_busy,
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                    counterText: '',
                  ),
                ),
                if (!_editing) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Files (${_files.length}/$maxFilesPerReport)',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _addFiles,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Take a photo of the report, or choose photos or a '
                        'PDF from your phone. Up to 10 MB each.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final file in _files)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox.square(
                          dimension: 48,
                          child:
                              file.isImage
                                  ? Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                    cacheWidth: 144,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            const Icon(Icons.image_outlined),
                                  )
                                  : const Icon(Icons.picture_as_pdf_outlined),
                        ),
                      ),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(formatFileSize(file.size)),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed:
                            _busy
                                ? null
                                : () => setState(() => _files.remove(file)),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                if (progress != null) ...[
                  // Reaching 100% means sent; the server is then saving.
                  LinearProgressIndicator(
                    value: progress < 1 ? progress : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress < 1
                        ? 'Uploading ${(progress * 100).round()}%'
                        : 'Saving...',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                SubmitButton(
                  label: _editing ? 'Save' : 'Upload',
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
