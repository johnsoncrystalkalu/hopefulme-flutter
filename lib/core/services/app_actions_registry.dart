import 'package:hopefulme_flutter/app/theme/theme_controller.dart';

class AppActionsRegistry {
  AppActionsRegistry._();

  static ThemeController? themeController;
  static Future<void> Function()? checkForUpdates;
}
