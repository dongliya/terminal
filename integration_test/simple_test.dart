import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/main.dart';
import 'package:terminal/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('app boots to connections screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TerminalApp());
    await tester.pumpAndSettle();
    expect(find.text('Remote Terminal'), findsOneWidget);
  });
}
