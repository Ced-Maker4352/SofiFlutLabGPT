import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../../services/two_step_generation_service.dart';
import '../../services/user_preferences_service.dart';

class PremiumStudioController extends ChangeNotifier {
  final TwoStepGenerationService _service;

  PremiumStudioController(this._service);

  bool _isLoading = false;
  bool _bodyLocked = false;

  Uint8List? _identityLockedImage;
  Uint8List? _finalStyledImage;

  bool get isLoading => _isLoading;
  bool get bodyLocked => _bodyLocked;

  Uint8List? get identityLockedImage => _identityLockedImage;
  Uint8List? get finalStyledImage => _finalStyledImage;

  Future<void> runStep1(
    Uint8List baseImage,
    String prompt,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final isMale = UserPreferencesService.instance.isMaleMode;
      _identityLockedImage = await _service.runStep1IdentityLock(
        baseImage,
        prompt,
        isMale: isMale,
      );
      _bodyLocked = true;
    } catch (e) {
      debugPrint('❌ PremiumStudioController.runStep1 failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runStep2(String prompt) async {
    if (_identityLockedImage == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final isMale = UserPreferencesService.instance.isMaleMode;
      _finalStyledImage = await _service.generateStyledOnly(
        _identityLockedImage!,
        prompt,
        isMale: isMale,
      );
    } catch (e) {
      debugPrint('❌ PremiumStudioController.runStep2 failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _identityLockedImage = null;
    _finalStyledImage = null;
    _bodyLocked = false;
    notifyListeners();
  }
}
