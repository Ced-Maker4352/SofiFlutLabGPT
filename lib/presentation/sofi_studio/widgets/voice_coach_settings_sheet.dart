import 'package:flutter/material.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_theme.dart';
import 'package:sofi_test_connect/services/voice_coach_service.dart';
import 'package:sofi_test_connect/services/audio_service.dart';

/// Bottom sheet for quick Voice Coach settings
class VoiceCoachSettingsSheet extends StatefulWidget {
  const VoiceCoachSettingsSheet({super.key});

  @override
  State<VoiceCoachSettingsSheet> createState() => _VoiceCoachSettingsSheetState();
}

class _VoiceCoachSettingsSheetState extends State<VoiceCoachSettingsSheet> {
  bool _loading = true;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final vc = VoiceCoachService.instance;
      await vc.initialize();
      _enabled = vc.enabled;
    } catch (e) {
      debugPrint('[VC Settings] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Voice Coach', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: SofiStudioTheme.charcoal)),
                          SizedBox(height: 2),
                          Text('Pre-recorded premium voice', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      Switch(
                        value: _enabled,
                        activeColor: SofiStudioTheme.purple,
                        onChanged: (v) async {
                          if (!mounted) return;
                          setState(() => _enabled = v);
                          await VoiceCoachService.instance.setEnabled(v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading
                              ? null
                              : () async {
                                  await AudioService.instance.playClick();
                                  await VoiceCoachService.instance.playPreview();
                                },
                          icon: const Icon(Icons.volume_up, color: Colors.white),
                          label: const Text('Preview Voice', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SofiStudioTheme.purple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Close', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
