// studio_transfer_service.dart
class StudioTransferService {
  StudioTransferService._private();
  static final instance = StudioTransferService._private();

  String? incomingImageUrl; // Last premium result to send into Studio
}
