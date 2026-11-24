// Whole-system test: the real app on a phone or emulator, talking to a real
// MedRec API and database. Run it through system-test/run.mjs (from the
// project root), which starts a throwaway backend, passes the values below,
// and afterwards checks the same record through the web viewer and the RFID
// bridge.
//
// Only the native photo and file pickers are replaced, because their screens
// belong to Android, not to this app. The chosen files are still real files
// on the device and are really uploaded.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medrec/core/session.dart';
import 'package:medrec/main.dart';
import 'package:path_provider/path_provider.dart';

const email = String.fromEnvironment('SYSTEM_EMAIL');
const password = String.fromEnvironment('SYSTEM_PASSWORD');
const cardAsTyped = String.fromEnvironment('SYSTEM_CARD'); // e.g. "5a:3f:..."
const name = 'Meera System Test';

class _FakeImagePicker extends ImagePickerPlatform {
  _FakeImagePicker(this.photo);
  final String photo;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [XFile(photo)];
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.pdf);
  final File pdf;

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
    PlatformFile(
      path: pdf.path,
      name: 'discharge summary.pdf',
      size: pdf.lengthSync(),
    ),
  ]);
}

/// Draws a small "scan" so the uploaded photo is a real, viewable image.
Future<List<int>> _drawPhoto() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 600, 400),
    Paint()..color = const Color(0xFFF3F6FA),
  );
  for (var i = 0; i < 8; i++) {
    canvas.drawRect(
      Rect.fromLTWH(40, 40.0 + i * 42, 300.0 + (i * 37) % 200, 18),
      Paint()..color = const Color(0xFF5B7DB1),
    );
  }
  final image = await recorder.endRecording().toImage(600, 400);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  assert(email.isNotEmpty && password.isNotEmpty && cardAsTyped.isNotEmpty);
  final cardId = cardAsTyped.replaceAll(RegExp(r'[\s:-]'), '').toUpperCase();

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// Pumps until [finder] matches: real network calls finish on their own
  /// schedule, so pumpAndSettle alone can return too early.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        final onScreen = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .join(' | ');
        throw TestFailure(
          'Timed out waiting for $finder\nOn screen: $onScreen',
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final page = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(finder, 200, scrollable: page.first);
    }
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await reveal(tester, find.text(text));
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String text) async {
    final button = find.widgetWithText(FilledButton, text);
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await reveal(tester, field(label));
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  Future<void> choose(WidgetTester tester, String label, String option) async {
    await reveal(tester, find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  /// Adds one entry to a record list from its screen.
  Future<void> addEntry(
    WidgetTester tester,
    String addLabel,
    Map<String, String> fields, {
    Map<String, String> choices = const {},
  }) async {
    await tapText(tester, addLabel);
    for (final MapEntry(:key, :value) in fields.entries) {
      await type(tester, key, value);
    }
    for (final MapEntry(:key, :value) in choices.entries) {
      await choose(tester, key, value);
    }
    await tapButton(tester, 'Save');
    // The form closes once the server has saved the entry.
    await waitFor(tester, find.text(addLabel));
    expect(field(fields.keys.first), findsNothing);
    expect(find.text(fields.values.first), findsOneWidget);
  }

  Future<Object?> callApi(String method, String path, [Object? body]) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('$defaultBaseUrl/api$path'),
      );
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return {'status': response.statusCode, 'body': jsonDecode(text)};
    } finally {
      client.close();
    }
  }

  testWidgets('a patient builds their record and it reaches the card lookup', (
    tester,
  ) async {
    // Start from a clean install state.
    await const FlutterSecureStorage().deleteAll();
    final dir = await getTemporaryDirectory();
    final photo = File('${dir.path}/scaled_blood_test.png')
      ..writeAsBytesSync(await _drawPhoto());
    final pdf = File('${dir.path}/discharge.pdf')..writeAsStringSync(
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[]/Count 0>>endobj\n'
      'trailer<</Root 1 0 R>>\n%%EOF\n',
    );
    ImagePickerPlatform.instance = _FakeImagePicker(photo.path);
    FilePickerPlatform.instance = _FakeFilePicker(pdf);

    await tester.pumpWidget(const ProviderScope(child: MedRecApp()));
    await waitFor(tester, find.text('Log in to manage your medical record.'));

    // 1. Sign up.
    await tapText(tester, 'Create an account');
    await type(tester, 'Full name', name);
    await type(tester, 'Username', 'meera_${cardId.toLowerCase()}');
    await type(tester, 'Email', email);
    await type(tester, 'Password', password);
    await tapButton(tester, 'Create account');
    await waitFor(tester, find.text('Profile and conditions'));
    expect(find.text(name), findsOneWidget);

    // 2. Profile and a condition.
    await tapText(tester, 'Profile and conditions');
    await type(tester, 'Age', '41');
    await choose(tester, 'Blood group', 'O-');
    await tapText(tester, 'Diabetes');
    await tapButton(tester, 'Save');
    await waitFor(tester, find.text('Profile saved'));
    expect(field('Full name *'), findsNothing, reason: 'back on home');

    // 3. Record lists.
    await tapText(tester, 'Allergies');
    await addEntry(
      tester,
      'Add allergy',
      {'Allergic to *': 'Penicillin', 'Reaction *': 'Hives'},
      choices: {'Severity *': 'Severe'},
    );
    await back(tester);

    await tapText(tester, 'Medications');
    await addEntry(tester, 'Add medication', {
      'Medicine name *': 'Metformin',
      'Dosage': '500mg',
    });
    await back(tester);

    await tapText(tester, 'Emergency contacts');
    await addEntry(tester, 'Add contact', {
      'Name *': 'Nisha Shah',
      'Phone number *': '+91 90000 00001',
      'Relationship': 'Sister',
    });
    await back(tester);

    // 4. A report with a photo and a PDF.
    await tapText(tester, 'Reports and photos');
    await tapText(tester, 'Add report');
    await type(tester, 'Title *', 'Blood test');
    await tapText(tester, 'Add');
    await tapText(tester, 'Choose photos');
    // Picked files are checked on disk before they are listed.
    await waitFor(tester, find.text('blood_test.png'));
    await tapText(tester, 'Add');
    await tapText(tester, 'Choose a PDF');
    await waitFor(tester, find.text('Files (2/10)'));
    await reveal(tester, find.text('discharge summary.pdf'));
    await tapButton(tester, 'Upload');
    await waitFor(tester, find.text('Report uploaded'));

    await tapText(tester, 'Blood test');
    await waitFor(tester, find.text('Files (2)'));
    await tapText(tester, 'blood_test.png');
    // The full-size photo comes from the API with the login token.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('This image could not be shown.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await back(tester); // viewer
    await back(tester); // report
    await back(tester); // reports

    // 5. Link the card, typed the way a reader prints it.
    await tapText(tester, 'RFID card');
    await type(tester, 'Card ID', cardAsTyped);
    await tapButton(tester, 'Link card');
    await waitFor(tester, find.text('Card linked'));
    expect(find.text(cardId), findsOneWidget);

    // 6. What anyone with the card sees (public lookup).
    final lookup =
        await callApi('GET', '/records/user/card/$cardId') as Map;
    expect(lookup['status'], 200);
    final record = lookup['body'] as Map;
    expect(record['name'], name);
    expect(record['blood_group'], 'O-');
    expect(record['age'], 41);
    expect((record['diabetic'] as Map)['status'], true);
    expect((record['allergies'] as List).single['allergens'], 'Penicillin');
    expect((record['medications'] as List).single['name'], 'Metformin');
    expect(
      (record['emergency_contact'] as List).single['phone_number'],
      '+91 90000 00001',
    );
    expect(jsonEncode(record), isNot(contains(email)));
    expect(jsonEncode(record), isNot(contains('Blood test')));

    // 7. A clinician logs their visit; the patient sees it.
    final visit = await callApi('POST', '/records/visitor', {
      'name': 'Dr Mehta',
      'purpose': 'Emergency room',
      'card_Id': cardId,
    }) as Map;
    expect(visit['status'], 201);
    await back(tester);
    await tapText(tester, 'RFID card');
    await waitFor(tester, find.text('Dr Mehta'));
    await back(tester);

    // 8. Log out and back in: everything is still there.
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Log out');
    await waitFor(tester, find.text('Log in to manage your medical record.'));
    await type(tester, 'Email', email.toUpperCase());
    await type(tester, 'Password', password);
    await tapButton(tester, 'Log in');
    await waitFor(tester, find.text(name));
    // Home rows, top to bottom (the list builds rows as they scroll in).
    await reveal(tester, find.text('Diabetes'));
    await reveal(tester, find.text('1 report'));
    await reveal(tester, find.text('Linked: $cardId'));
  });
}
