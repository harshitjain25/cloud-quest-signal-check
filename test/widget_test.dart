import 'package:cloud_quest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSignIn(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
  }

  testWidgets('Empty login fields show validation errors', (tester) async {
    await openSignIn(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('Invalid email is rejected', (tester) async {
    await openSignIn(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'ExamplePassword123!',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Please wait...'), findsNothing);
  });

  testWidgets('Registration rejects a short password', (tester) async {
    await openSignIn(tester);

    await tester.tap(find.text('New learner? Create an account'));
    await tester.pump();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'learner@example.com',
    );

    await tester.enterText(find.byType(TextFormField).at(1), '123');

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(find.text('Please wait...'), findsNothing);
  });
}
