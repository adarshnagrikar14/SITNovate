import 'package:flutter/material.dart';

class GlobalContext {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;
}
