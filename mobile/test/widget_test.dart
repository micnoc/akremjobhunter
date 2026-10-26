import 'package:flutter_test/flutter_test.dart';
import 'package:akremjobhunter/main.dart';

void main() {
  testWidgets('AkremJobHunterApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AkremJobHunterApp());
    expect(find.byType(AkremJobHunterApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
