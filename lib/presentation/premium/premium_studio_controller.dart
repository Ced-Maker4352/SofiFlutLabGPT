import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/two_step_generation_service.dart';

class PremiumStudioController extends ChangeNotifier {
  final TwoStepGenerationService _service;

  PremiumStudioController(this._service);

  bool _isLoading = false;
  bool _bodyLocked = false;

  String? step1Image;
  String? finalImage;

  bool get isLoading => _isLoading;
  bool get bodyLocked => _bodyLocked;

  Future<void> runStep1(String headshotBase64) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.runPipeline(userHeadshotBase64: headshotBase64);
      step1Image = result.step1FullBodyBase64;
      finalImage = result.finalStylizedBase64;
      _bodyLocked = true;
    } catch (e) {
      debugPrint('❌ PremiumStudioController.runStep1 failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
