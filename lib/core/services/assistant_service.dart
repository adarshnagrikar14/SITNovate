import 'package:flutter/material.dart';
import 'package:sybot/core/widgets/assistant_bottom_sheet.dart';

class AssistantService {
  static Future<void> showAssistant(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => const AssistantBottomSheet(),
    );
  }
}
