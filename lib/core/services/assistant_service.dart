import 'package:flutter/material.dart';
import 'package:sybot/core/widgets/assistant_bottom_sheet.dart';

class AssistantService {
  static void showAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AssistantBottomSheet(),
    );
  }
}
