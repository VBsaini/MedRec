import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../models/report.dart';
import 'report_form_screen.dart';
import 'reports_controller.dart';

/// All of the patient's uploaded reports.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports and photos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const ReportFormScreen(),
              ),
            ),
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Add report'),
      ),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your reports',
              message: '$error',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(reportsProvider),
            ),
        data:
            (list) => RefreshIndicator(
              onRefresh: () => ref.refresh(reportsProvider.future),
              child:
                  list.isEmpty
                      ? LayoutBuilder(
                        // Scrollable so pull-to-refresh works when empty.
                        builder:
                            (context, constraints) => SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: const EmptyState(
                                  icon: Icons.folder_copy_outlined,
                                  title: 'No reports yet',
                                  message:
                                      'Upload photos or PDFs of lab reports, '
                                      'prescriptions and scans to keep them '
                                      'with your record.',
                                ),
                              ),
                            ),
                      )
                      : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder:
                            (context, index) =>
                                _ReportTile(report: list[index]),
                      ),
            ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final count = report.files.length;
    final details = [
      report.categoryLabel,
      if (report.date != null) formatDate(report.date),
      count == 0 ? 'No files' : '$count ${count == 1 ? 'file' : 'files'}',
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(report.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(details.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/reports/${report.id}'),
      ),
    );
  }
}
