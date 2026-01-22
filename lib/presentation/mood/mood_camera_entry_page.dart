import 'package:flutter/material.dart';

// Platform-safe conditional imports
import 'mood_camera_entry_page_web.dart'
    if (dart.library.io) 'mood_camera_entry_page_mobile.dart';

/// ✅ THIS IS THE PUBLIC CLASS SPLASH PAGE MUST SEE
class MoodCameraEntryPage extends StatelessWidget {
  const MoodCameraEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoodCameraEntryPageImpl();
  }
}
