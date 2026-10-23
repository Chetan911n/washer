import 'package:flutter_test/flutter_test.dart';
import 'package:society_wash/main.dart';

void main() {
  testWidgets('setup screen renders when Supabase credentials are absent', (
    tester,
  ) async {
    await tester.pumpWidget(const SocietyWashApp());
    expect(find.text('Society Wash'), findsOneWidget);
    expect(find.textContaining('Connect this app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('minimum app version gate compares release and build versions', () {
    expect(isVersionOlderThan('0.1.0+1', '0.1.0+2'), isTrue);
    expect(isVersionOlderThan('0.2.0+1', '0.1.9+99'), isFalse);
    expect(isVersionOlderThan('0.1.0+2', '0.1.0+2'), isFalse);
  });

  testWidgets('web preview shows the four entry choices without backend access',
      (
    tester,
  ) async {
    await tester.pumpWidget(const SocietyWashApp(previewMode: true));
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Washer'), findsOneWidget);
    expect(find.text('Register'), findsNWidgets(2));
    expect(find.text('Log in'), findsNWidgets(2));
    expect(find.textContaining('Preview only'), findsOneWidget);

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Preview only'), findsOneWidget);
    expect(find.textContaining('OTP delivery is disabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
