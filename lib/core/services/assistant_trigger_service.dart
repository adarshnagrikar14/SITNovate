import 'package:flutter/services.dart';
import 'package:sybot/core/services/assistant_service.dart';
import 'package:sybot/core/utils/global_context.dart';

class AssistantTriggerService {
  static const platform = MethodChannel('com.sybot/assistant');
  static bool _isShowing = false;

  static Future<void> initialize() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'triggerAssistant' && !_isShowing) {
        final context = GlobalContext.context;
        if (context != null) {
          _isShowing = true;
          await AssistantService.showAssistant(context);
          _isShowing = false;
        }
      }
    });
  }
}
