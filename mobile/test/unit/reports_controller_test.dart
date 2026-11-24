import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/features/auth/auth_controller.dart';
import 'package:medrec/features/reports/attachments.dart';
import 'package:medrec/features/reports/reports_controller.dart';

import '../support/fake_server.dart';

Map<String, dynamic> _report(String id, String date, {List<Map>? files}) => {
  '_id': id,
  'title': 'Report $id',
  'category': 'lab_report',
  'date': '${date}T00:00:00.000Z',
  'files': files ?? [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServer server;
  late ProviderContainer container;
  late ReportsController reports;

  List<String> ids() => [
    for (final r in container.read(reportsProvider).requireValue) r.id,
  ];

  setUp(() async {
    server =
        FakeServer()
          ..on('GET', '/auth/me', (_) => {'_id': 'u1', 'name': 'Asha'})
          ..on(
            'GET',
            '/reports',
            (_) => [_report('b', '2024-05-01'), _report('a', '2023-01-10')],
          );
    container = ProviderContainer(
      overrides: fakeBackendOverrides(server, stored: {'token': 't'}),
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).restore();
    await container.read(reportsProvider.future);
    reports = container.read(reportsProvider.notifier);
  });

  test('loads the list from the server', () {
    expect(ids(), ['b', 'a']);
    expect(container.read(reportsProvider).requireValue.first.categoryLabel, 'Lab report');
  });

  test('an edited report moves to its new place by date', () async {
    server.on('PATCH', '/reports/:id', (r) {
      expect(r.json, {
        'title': 'Old scan',
        'category': 'scan',
        'description': '',
        'date': '2020-02-29',
      });
      return _report('b', '2020-02-29');
    });
    await reports.updateDetails(
      'b',
      title: 'Old scan',
      category: 'scan',
      date: DateTime(2020, 2, 29),
      description: '',
    );
    expect(ids(), ['a', 'b']);
  });

  test('deleting a report removes it from the list', () async {
    server.on('DELETE', '/reports/:id', (_) => {'message': 'Report deleted'});
    await reports.delete('b');
    expect(ids(), ['a']);
    expect(server.requests.last.path, '/reports/b');
  });

  test('deleting a file keeps the report with the files that remain', () async {
    server.on('DELETE', '/reports/:id/files/:fileId', (r) {
      expect(r.params, {'id': 'a', 'fileId': 'f1'});
      return _report('a', '2023-01-10');
    });
    await reports.deleteFile('a', 'f1');
    expect(container.read(reportsProvider).requireValue.last.files, isEmpty);
  });

  test('creating a report uploads the files with their names and types', () async {
    final dir = await Directory.systemTemp.createTemp('medrec_test');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File('${dir.path}/scaled_x.jpg')..writeAsBytesSync(List.filled(2000, 1));
    final pdf = File('${dir.path}/cbc.pdf')..writeAsBytesSync(List.filled(500, 2));

    server.on('POST', '/reports', (r) {
      final form = r.form!;
      expect(Map.fromEntries(form.fields), {
        'title': 'CBC',
        'category': 'lab_report',
        'description': 'Fasting',
        'date': '2024-06-02',
      });
      expect(form.files.map((f) => f.key), ['files', 'files']);
      expect(form.files.map((f) => f.value.filename), ['Blood test.jpg', 'cbc.pdf']);
      expect(
        form.files.map((f) => f.value.contentType.toString()),
        ['image/jpeg', 'application/pdf'],
      );
      return Reply(
        201,
        _report(
          'c',
          '2024-06-02',
          files: [
            {'_id': 'f1', 'originalName': 'Blood test.jpg', 'mimeType': 'image/jpeg'},
            {'_id': 'f2', 'originalName': 'cbc.pdf', 'mimeType': 'application/pdf'},
          ],
        ),
      );
    });

    final progress = <double>[];
    final created = await reports.create(
      title: 'CBC',
      category: 'lab_report',
      date: DateTime(2024, 6, 2),
      description: 'Fasting',
      files: [
        Attachment(path: photo.path, name: 'Blood test.jpg', mimeType: 'image/jpeg', size: 2000),
        Attachment(path: pdf.path, name: 'cbc.pdf', mimeType: 'application/pdf', size: 500),
      ],
      onProgress: progress.add,
    );

    expect(created.files, hasLength(2));
    expect(ids(), ['c', 'b', 'a']);
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });
}
