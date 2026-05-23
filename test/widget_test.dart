import 'package:digital_acadmy/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Digital Academy app moves from splash to login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DigitalAcademyApp()),
    );

    expect(find.text('Digital Academy'), findsOneWidget);
    expect(find.text('University Student Portal'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
