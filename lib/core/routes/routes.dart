import 'package:flutter/material.dart';
import 'package:sybot/features/home/ui/home_screen.dart';
import 'package:sybot/features/splash/ui/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';

  static Map<String, Widget Function(BuildContext)> routes = {
    splash: (context) => const SplashScreen(),
    home: (context) => const HomeScreen(),
  };
}
