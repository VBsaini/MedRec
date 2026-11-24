import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/report.dart';
import '../auth/auth_controller.dart';
import 'attachments.dart';

/// Upload progress from 0.0 to 1.0.
typedef ProgressListener = void Function(double fraction);

/// The logged-in patient's reports, newest first, plus every way to change
/// them. Each change updates the list from the server's response.
class ReportsController extends AsyncNotifier<List<Report>> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<List<Report>> build() async {
    // Reload if a different patient logs in.
    ref.watch(patientProvider.select((p) => p.id));
    final data = await ref.watch(apiClientProvider).get('/reports');
    return [for (final item in data as List) _toReport(item)];
  }

  Future<Report> create({
    required String title,
    required String category,
    required DateTime? date,
    required String description,
    required List<Attachment> files,
    ProgressListener? onProgress,
  }) async {
    final form = await _toFormData(files);
    form.fields.addAll([
      MapEntry('title', title),
      MapEntry('category', category),
      MapEntry('description', description),
      MapEntry('date', dateToWire(date)),
    ]);
    return _store(
      await _api.post(
        '/reports',
        data: form,
        onSendProgress: _progress(onProgress),
      ),
    );
  }

  Future<Report> updateDetails(
    String id, {
    required String title,
    required String category,
    required DateTime? date,
    required String description,
  }) async {
    return _store(
      await _api.patch(
        '/reports/$id',
        data: {
          'title': title,
          'category': category,
          'description': description,
          'date': dateToWire(date),
        },
      ),
    );
  }

  Future<Report> addFiles(
    String id,
    List<Attachment> files, {
    ProgressListener? onProgress,
  }) async {
    return _store(
      await _api.post(
        '/reports/$id/files',
        data: await _toFormData(files),
        onSendProgress: _progress(onProgress),
      ),
    );
  }

  Future<void> deleteFile(String id, String fileId) async {
    _store(await _api.delete('/reports/$id/files/$fileId'));
  }

  Future<void> delete(String id) async {
    await _api.delete('/reports/$id');
    state = AsyncData([
      for (final r in state.valueOrNull ?? const <Report>[])
        if (r.id != id) r,
    ]);
  }

  Future<FormData> _toFormData(List<Attachment> files) async {
    final form = FormData();
    for (final file in files) {
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(
            file.path,
            filename: file.name,
            // The server decides what is allowed from this type.
            contentType: DioMediaType.parse(file.mimeType),
          ),
        ),
      );
    }
    return form;
  }

  ProgressCallback? _progress(ProgressListener? listener) {
    if (listener == null) return null;
    return (sent, total) {
      if (total > 0) listener(sent / total);
    };
  }

  /// Puts a report the server returned into the list (replacing its old
  /// version if present) and keeps the list sorted newest first.
  Report _store(dynamic json) {
    final report = _toReport(json);
    final others = [
      for (final r in state.valueOrNull ?? const <Report>[])
        if (r.id != report.id) r,
    ];
    final epoch = DateTime(0);
    state = AsyncData(
      [report, ...others]
        ..sort((a, b) => (b.date ?? epoch).compareTo(a.date ?? epoch)),
    );
    return report;
  }

  Report _toReport(dynamic json) =>
      Report.fromJson(Map<String, dynamic>.from(json as Map));
}

final reportsProvider = AsyncNotifierProvider<ReportsController, List<Report>>(
  ReportsController.new,
);
