import 'package:flutter/material.dart';

import 'shell/app.dart';
import 'shell/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsController = SettingsController();
  await settingsController.load();
  runApp(PravaApp(settingsController: settingsController));
}
