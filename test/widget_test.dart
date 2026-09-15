import 'package:flutter_test/flutter_test.dart';

import 'package:sd_app/main.dart';

void main() {
  testWidgets('shows bootstrap loading state', (WidgetTester tester) async {
    await tester.pumpWidget(const SdApp());

    expect(find.text('正在连接...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
