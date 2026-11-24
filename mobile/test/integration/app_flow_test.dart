// The whole app (router, screens, state, API client) running against an
// in-memory fake of the API. Covers the flows a patient goes through.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medrec/main.dart';

import '../support/fake_backend.dart';
import '../support/fake_server.dart' show fakeBackendOverrides;

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend());

  /// Starts the app on a phone-sized screen, optionally already logged in.
  Future<void> launch(WidgetTester tester, {String? token}) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeBackendOverrides(
          backend.server,
          stored: {if (token != null) 'token': token},
        ),
        child: const MedRecApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// Scrolls the page until [finder] is built and on screen. List rows far
  /// down the page do not exist until scrolled to.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      // The page's vertical list (text fields have horizontal scrollables).
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

  Future<void> choose(WidgetTester tester, String dropdownLabel, String option) async {
    await reveal(tester, find.text(dropdownLabel));
    await tester.tap(find.text(dropdownLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  /// The text of the home screen tile with [title].
  Future<String> tileSubtitle(WidgetTester tester, String title) async {
    await reveal(tester, find.text(title));
    final tile = find.ancestor(of: find.text(title), matching: find.byType(ListTile));
    final texts = tester.widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)));
    return texts.map((t) => t.data).where((d) => d != title).join();
  }

  group('accounts', () {
    testWidgets('sign up checks the form, then lands on home', (tester) async {
      await launch(tester);
      expect(find.text('Log in to manage your medical record.'), findsOneWidget);

      await tapText(tester, 'Create an account');
      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.tap(submit); // the empty form
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Use 3-30 letters, numbers, _ . or -'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(backend.server.requests, isEmpty, reason: 'nothing sent');

      await tester.enterText(field('Full name'), 'Asha Rao');
      await tester.enterText(field('Username'), 'asha_rao');
      await tester.enterText(field('Email'), 'asha@example.com');
      await tester.enterText(field('Password'), 'long-password');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing, reason: 'left the form');
      expect(await tileSubtitle(tester, 'RFID card'), 'No card linked');
      expect(backend.user('asha@example.com')['alias'], 'asha_rao');
    });

    testWidgets('a wrong password shows the server message', (tester) async {
      backend.addUser(name: 'Asha', email: 'asha@example.com', password: 'right-one');
      await launch(tester);

      await tester.enterText(field('Email'), 'asha@example.com');
      await tester.enterText(field('Password'), 'wrong-one');
      await tapText(tester, 'Log in');
      expect(find.text('Invalid email or password.'), findsOneWidget);

      await tester.enterText(field('Password'), 'right-one');
      await tapText(tester, 'Log in');
      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('Invalid email or password.'), findsNothing);
    });

    testWidgets('a saved login opens straight to home', (tester) async {
      final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
      await launch(tester, token: token);
      expect(find.text('Kabir Shah'), findsOneWidget);
    });

    testWidgets('server down at start-up: retry recovers', (tester) async {
      final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
      backend.server.down = true;
      await launch(tester, token: token);
      expect(find.textContaining('Cannot reach the server'), findsOneWidget);

      backend.server.down = false;
      await tapText(tester, 'Try again');
      expect(find.text('Kabir Shah'), findsOneWidget);
    });

    testWidgets('an expired login sends the user back to log in', (tester) async {
      final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
      await launch(tester, token: token);

      backend.expireAllTokens();
      await tapText(tester, 'Allergies');
      await tapText(tester, 'Add allergy');
      await tester.enterText(field('Allergic to *'), 'Dust');
      await tester.enterText(field('Reaction *'), 'Sneezing');
      await choose(tester, 'Severity *', 'Mild');
      await tapText(tester, 'Save');

      expect(find.text('Log in to manage your medical record.'), findsOneWidget);
    });

    testWidgets('log out asks first', (tester) async {
      final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
      await launch(tester, token: token);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Cancel');
      expect(find.text('Kabir Shah'), findsOneWidget);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Log out');
      expect(find.text('Log in to manage your medical record.'), findsOneWidget);
    });
  });

  testWidgets('saving the profile returns home once and shows the change', (tester) async {
    final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
    await launch(tester, token: token);

    await tapText(tester, 'Profile and conditions');
    await tester.enterText(field('Age'), '52');
    await choose(tester, 'Blood group', 'AB-');
    await tapText(tester, 'Diabetes');
    await tapText(tester, 'Save');

    // Regression: saving used to re-open the profile screen.
    expect(find.text('Profile and conditions'), findsOneWidget);
    expect(find.text('Full name *'), findsNothing);
    expect(find.text('Profile saved'), findsOneWidget);
    expect(await tileSubtitle(tester, 'Profile and conditions'), 'Diabetes');

    final saved = backend.user('k@example.com');
    expect(saved['age'], 52);
    expect(saved['blood_group'], 'AB-');
    expect((saved['diabetic'] as Map)['status'], isTrue);
  });

  testWidgets('allergies: validate, add, edit and delete', (tester) async {
    final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
    await launch(tester, token: token);
    expect(await tileSubtitle(tester, 'Allergies'), 'None added');

    await tapText(tester, 'Allergies');
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tapText(tester, 'Add allergy');
    await tapText(tester, 'Save');
    expect(find.text('Required'), findsNWidgets(3));

    await tester.enterText(field('Allergic to *'), 'Penicillin');
    await tester.enterText(field('Reaction *'), 'Rash');
    await choose(tester, 'Severity *', 'Severe');
    await tapText(tester, 'Save');
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Severe · Rash'), findsOneWidget);

    await tapText(tester, 'Penicillin');
    expect(find.text('Edit allergy'), findsOneWidget);
    await tester.enterText(field('Allergic to *'), 'Amoxicillin');
    await tapText(tester, 'Save');
    expect(find.text('Amoxicillin'), findsOneWidget);
    expect(find.text('Penicillin'), findsNothing);

    await tapText(tester, 'Amoxicillin');
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this allergy?'), findsOneWidget);
    await tapText(tester, 'Delete');
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await tileSubtitle(tester, 'Allergies'), 'None added');
  });

  testWidgets('emergency contacts show on home as a count', (tester) async {
    final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
    await launch(tester, token: token);

    await tapText(tester, 'Emergency contacts');
    for (final (name, phone) in [('Nisha', '+91 90000 00001'), ('Ravi', '98765 43210')]) {
      await tapText(tester, 'Add contact');
      await tester.enterText(field('Name *'), name);
      await tester.enterText(field('Phone number *'), phone);
      await tapText(tester, 'Save');
    }
    expect(find.text('Nisha'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await tileSubtitle(tester, 'Emergency contacts'), '2 entries');
  });

  group('RFID card', () {
    testWidgets('link, see visitors, unlink', (tester) async {
      final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
      await launch(tester, token: token);

      await tapText(tester, 'RFID card');
      expect(find.text('No one has signed in as a visitor yet.'), findsOneWidget);

      await tester.enterText(field('Card ID'), '04:a');
      await tapText(tester, 'Link card');
      expect(find.text('Enter the 4-32 letters and digits on the reader'), findsOneWidget);

      await tester.enterText(field('Card ID'), '04:a1:b2:c3');
      await tapText(tester, 'Link card');
      expect(find.text('04A1B2C3'), findsOneWidget);
      expect(find.text('Card linked'), findsOneWidget);

      await tapText(tester, 'Unlink');
      await tapText(tester, 'Unlink'); // the confirm dialog's button
      expect(find.text('Card unlinked'), findsOneWidget);
      expect(field('Card ID'), findsOneWidget);
      expect(backend.user('k@example.com')['card_Id'], isNull);
    });

    testWidgets("someone else's card is refused with a clear message", (tester) async {
      backend.addUser(name: 'Other', email: 'o@example.com', extra: {'card_Id': 'MED001'});
      final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
      await launch(tester, token: token);

      await tapText(tester, 'RFID card');
      await tester.enterText(field('Card ID'), 'med001');
      await tapText(tester, 'Link card');
      expect(find.text('That card is already linked to another account.'), findsOneWidget);
      expect(field('Card ID'), findsOneWidget);
    });

    testWidgets('access history lists who scanned the card', (tester) async {
      final token = backend.addUser(
        name: 'Kabir Shah',
        email: 'k@example.com',
        extra: {'card_Id': 'D00D0003'},
      );
      backend.visitors[backend.user('k@example.com')['_id'] as String] = [
        {
          'name': 'Dr Mehta',
          'purpose': 'Emergency room',
          'visitDate': DateTime(2026, 11, 24, 9, 30).toUtc().toIso8601String(),
        },
      ];
      await launch(tester, token: token);
      expect(await tileSubtitle(tester, 'RFID card'), 'Linked: D00D0003');

      await tapText(tester, 'RFID card');
      expect(find.text('Dr Mehta'), findsOneWidget);
      expect(find.text('24 Nov 2026, 9:30 AM · Emergency room'), findsOneWidget);
    });
  });

  testWidgets('a server error while saving keeps the form open', (tester) async {
    final token = backend.addUser(name: 'Kabir Shah', email: 'k@example.com');
    await launch(tester, token: token);
    await tapText(tester, 'Allergies');
    await tapText(tester, 'Add allergy');
    await tester.enterText(field('Allergic to *'), 'Latex');
    await tester.enterText(field('Reaction *'), 'Itching');
    await choose(tester, 'Severity *', 'Moderate');

    backend.server.down = true;
    await tapText(tester, 'Save');
    expect(find.textContaining('Cannot reach the server'), findsOneWidget);
    expect(field('Allergic to *'), findsOneWidget, reason: 'form still open');

    backend.server.down = false;
    await tapText(tester, 'Save');
    expect(find.text('Latex'), findsOneWidget);
  });
}
