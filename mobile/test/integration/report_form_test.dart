// Adding files to a new report, with the native pickers replaced.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:medrec/main.dart';

import '../support/fake_backend.dart';
import '../support/fake_server.dart' show fakeBackendOverrides;

class _FakeImagePicker extends ImagePickerPlatform {
  _FakeImagePicker(this.paths);
  final List<String> paths;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [for (final p in paths) XFile(p)];
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.files);
  final List<File> files;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async => FilePickerResult([
    for (final f in files)
      PlatformFile(
        path: f.path,
        name: f.uri.pathSegments.last,
        size: f.lengthSync(),
      ),
  ]);
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('medrec_form');
    addTearDown(() => dir.delete(recursive: true));
  });

  File file(String name, int bytes) =>
      File('${dir.path}${Platform.pathSeparator}$name')..writeAsBytesSync(List.filled(bytes, 1));

  testWidgets('photos and PDFs are listed with their real names', (tester) async {
    final backend = FakeBackend();
    final token = backend.addUser(name: 'Asha', email: 'a@example.com');
    final photo = file('scaled_blood_test.png', 3000);
    final pdf = file('discharge summary.pdf', 800);
    ImagePickerPlatform.instance = _FakeImagePicker([photo.path]);
    FilePickerPlatform.instance = _FakeFilePicker([pdf]);

    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeBackendOverrides(backend.server, stored: {'token': token}),
        child: const MedRecApp(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    // Picking reads file sizes from disk, which needs real async time.
    Future<void> pick(String source) async {
      await tap('Add');
      await tester.tap(find.text(source).last);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    await tester.scrollUntilVisible(
      find.text('Reports and photos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap('Reports and photos');
    await tap('Add report');
    await pick('Choose photos');
    expect(find.text('blood_test.png'), findsOneWidget);
    await pick('Choose a PDF');
    expect(find.text('discharge summary.pdf'), findsOneWidget);
    expect(find.text('Files (2/10)'), findsOneWidget);
  });
}
