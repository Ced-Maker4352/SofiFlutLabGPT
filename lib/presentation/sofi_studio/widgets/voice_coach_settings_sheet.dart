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
  bool _sayName = true;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneticCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneticCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final vc = VoiceCoachService.instance;
      await vc.initialize();
      _enabled = vc.enabled;
      _sayName = vc.sayName;
      _nameCtrl.text = vc.name ?? '';
      _phoneticCtrl.text = vc.phonetic ?? '';
    } catch (e) {
      debugPrint('[VC Settings] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneticCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    try {
      await VoiceCoachService.instance.setName(_nameCtrl.text);
    } catch (e) {
      debugPrint('[VC Settings] save name failed: $e');
    }
  }

  Future<void> _savePhonetic() async {
    try {
      final text = _phoneticCtrl.text.trim().isEmpty ? null : _phoneticCtrl.text;
      await VoiceCoachService.instance.setPhonetic(text);
    } catch (e) {
      debugPrint('[VC Settings] save phonetic failed: $e');
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
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Voice Coach', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SofiStudioTheme.charcoal)),
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
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Say my name', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SofiStudioTheme.charcoal)),
                        Switch(
                          value: _sayName,
                          activeColor: SofiStudioTheme.blue,
                          onChanged: (v) async {
                            if (!mounted) return;
                            setState(() => _sayName = v);
                            await VoiceCoachService.instance.setSayName(v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: SofiStudioTheme.charcoal),
                      decoration: const InputDecoration(
                        labelText: 'Preferred name',
                        hintText: 'e.g., Sophie',
                        labelStyle: TextStyle(color: SofiStudioTheme.charcoal),
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _saveName(),
                      onEditingComplete: _saveName,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneticCtrl,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: SofiStudioTheme.charcoal),
                      decoration: const InputDecoration(
                        labelText: 'Phonetic spelling (optional)',
                        hintText: 'e.g., Saw-fee',
                        labelStyle: TextStyle(color: SofiStudioTheme.charcoal),
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _savePhonetic(),
                      onEditingComplete: _savePhonetic,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loading
                              ? null
                              : () async {
                                  await AudioService.instance.playClick();
                                  final name = _phoneticCtrl.text.trim().isNotEmpty
                                      ? _phoneticCtrl.text.trim()
                                      : (_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'friend');
                                  await VoiceCoachService.instance.speak('Hi $name, I\'ll guide you here.');
                                },
                          icon: const Icon(Icons.volume_up, color: Colors.white),
                          label: const Text('Preview', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SofiStudioTheme.purple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
