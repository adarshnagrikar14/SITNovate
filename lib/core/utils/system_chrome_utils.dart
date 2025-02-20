import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemChromeUtils {
  static void setSystemUIOverlayStyle(
      {bool isDark = false,
      Color? statusBarColor,
      Color? systemNavigationBarColor}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            systemNavigationBarColor ?? const Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  static void setPreferredOrientations() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
