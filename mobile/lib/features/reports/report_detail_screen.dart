import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../models/report.dart';
import 'attachments.dart';
import 'report_form_screen.dart';
import 'reports_controller.dart';

/// One report: its details and files, with ways to add, view and delete.
class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  /// What is in progress, shown under the app bar; null when idle.
  String? _busyLabel;
  double? _progress;

  bool get _busy => _busyLabel != null;

  ReportsController get _reports => ref.read(reportsProvider.notifier);

  /// Runs [action] with a busy indicator and shows any API error.
  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busyLabel = label;
      _progress = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _addFiles(Report report) async {
    final picked = await pickAttachments(
      context,
      remaining: maxFilesPerReport - report.files.length,
    );
    if (picked.isEmpty) return;
    await _run('Uploading', () async {
      await _reports.addFiles(
        report.id,
        picked,
        onProgress: (fraction) {
          if (mounted) {
            setState(() => _progress = fraction < 1 ? fraction : null);
          }
        },
      );
    });
  }

  Future<void> _deleteFile(Report report, ReportFile file) async {
    final ok = await confirm(
      context,
      title: 'Delete this file?',
      message: '"${file.name}" will be permanently removed.',
    );
    if (!ok) return;
    await _run('Deleting', () => _reports.deleteFile(report.id, file.id));
  }

  Future<void> _deleteReport(Report report) async {
    final count = report.files.length;
    final ok = await confirm(
      context,
      title: 'Delete this report?',
      message:
          count == 0
              ? 'It will be permanently removed.'
              : 'The report and its $count ${count == 1 ? 'file' : 'files'} '
                  'will be permanently removed.',
    );
    if (!ok) return;
    await _run('Deleting', () async {
      await _reports.delete(report.id);
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _fileUrl(ReportFile file) =>
      '${ref.read(sessionProvider).baseUrl}/api/reports/${widget.reportId}'
      '/files/${file.id}';

  Future<void> _openFile(ReportFile file) async {
    if (file.isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => _ImageViewer(
                title: file.name,
                url: _fileUrl(file),
                headers: ref.read(sessionProvider).authHeaders,
              ),
        ),
      );
      return;
    }
    // PDFs are downloaded to the app's cache and handed to a viewer app.
    await _run('Opening', () async {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/medrec_${file.id}.pdf';
      await ref
          .read(apiClientProvider)
          .download('/reports/${widget.reportId}/files/${file.id}', path);
      final result = await OpenFilex.open(path, type: file.mimeType);
      if (result.type != ResultType.done && mounted) {
        showMessage(
          context,
          result.type == ResultType.noAppToOpen
              ? 'No app on this phone can open PDFs.'
              : 'Could not open the file.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportsProvider);
    final report =
        reports.valueOrNull?.where((r) => r.id == widget.reportId).firstOrNull;

    if (report == null) {
      return Scaffold(
        appBar: AppBar(),
        body:
            reports.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'Report not found',
                ),
      );
    }

    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        bottom:
            _busy
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(value: _progress),
                )
                : null,
        actions: [
          IconButton(
            tooltip: 'Edit details',
            icon: const Icon(Icons.edit_outlined),
            onPressed:
                _busy
                    ? null
                    : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => ReportFormScreen(report: report),
                      ),
                    ),
          ),
          IconButton(
            tooltip: 'Delete report',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : () => _deleteReport(report),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _addFiles(report),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add files'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(report.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            [
              report.categoryLabel,
              if (report.date != null) formatDate(report.date),
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if ((report.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(report.description!, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 24),
          Text(
            'Files (${report.files.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (report.files.isEmpty)
            Text(
              'No files attached.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final file in report.files)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 48,
                      child:
                          file.isImage
                              ? Image.network(
                                _fileUrl(file),
                                headers: session.authHeaders,
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
                  subtitle: Text(
                    [
                      file.isPdf ? 'PDF' : 'Photo',
                      formatFileSize(file.size),
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete file',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy ? null : () => _deleteFile(report, file),
                  ),
                  onTap: _busy ? null : () => _openFile(file),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen, zoomable view of one uploaded photo.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.title,
    required this.url,
    required this.headers,
  });

  final String title;
  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            headers: headers,
            fit: BoxFit.contain,
            loadingBuilder:
                (context, child, progress) =>
                    progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
            errorBuilder:
                (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This image could not be shown.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
