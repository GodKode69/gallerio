import 'package:flutter_test/flutter_test.dart';
import 'package:gallerio/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const GallerioApp());
    expect(find.text('Gallerio'), findsOneWidget);
  });
}
