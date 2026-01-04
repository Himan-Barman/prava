import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shell/app.dart';
import 'package:mobile/shell/settings_controller.dart';

void main() {
  testWidgets('Prava app builds', (WidgetTester tester) async {
    final settingsController = SettingsController();
    addTearDown(settingsController.dispose);

    await tester.pumpWidget(
      PravaApp(settingsController: settingsController),
    );
    expect(find.byType(PravaApp), findsOneWidget);
  });
}
