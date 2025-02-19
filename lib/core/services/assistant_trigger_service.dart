import 'package:flutter/services.dart';
import 'package:sybot/core/services/assistant_service.dart';
import 'package:sybot/core/utils/global_context.dart';

class AssistantTriggerService {
  static const platform = MethodChannel('com.sybot/assistant');

  static Future<void> initialize() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'triggerAssistant') {
        final context = GlobalContext.context;
        if (context != null) {
          AssistantService.showAssistant(context);
        }
        return;
      }
    });
  }
}
