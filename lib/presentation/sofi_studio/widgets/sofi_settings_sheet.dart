import 'package:flutter/material.dart';
import 'package:sofi_test_connect/services/performance_service.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_theme.dart';

class SofiSettingsSheet extends StatefulWidget {
  final bool autoSave;
  final ValueChanged<bool>? onAutoSaveChanged;

  const SofiSettingsSheet({
    super.key,
    required this.autoSave,
    this.onAutoSaveChanged,
  });

  @override
  State<SofiSettingsSheet> createState() => _SofiSettingsSheetState();
}

class _SofiSettingsSheetState extends State<SofiSettingsSheet> {
  late bool _performanceMode;
  
  @override
  void initState() {
    super.initState();
    _performanceMode = PerformanceService.instance.performanceMode;
    PerformanceService.instance.addListener(_onPerformanceChanged);
  }
  
  @override
  void dispose() {
    PerformanceService.instance.removeListener(_onPerformanceChanged);
    super.dispose();
  }
  
  void _onPerformanceChanged() {
    if (mounted) {
      setState(() {
        _performanceMode = PerformanceService.instance.performanceMode;
      });
    }
  }
  
  Future<void> _togglePerformanceMode(bool value) async {
    if (!mounted) return;
    setState(() => _performanceMode = value);
    await PerformanceService.instance.setPerformanceMode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: SofiStudioTheme.purple, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: SofiStudioTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Performance Mode (most important for stability)
                  _buildSettingRow(
                    icon: Icons.speed,
                    label: "Performance Mode",
                    subtitle: "Reduces effects for iPhone stability",
                    trailing: Switch(
                      value: _performanceMode,
                      onChanged: _togglePerformanceMode,
                      activeColor: SofiStudioTheme.purple,
                    ),
                  ),
                  const Divider(height: 24),
                  // Auto-save
                  _buildSettingRow(
                    icon: Icons.save,
                    label: "Auto-save creations",
                    subtitle: "Save images automatically after generation",
                    trailing: Switch(
                      value: widget.autoSave,
                      onChanged: widget.onAutoSaveChanged,
                      activeColor: SofiStudioTheme.purple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Placeholder settings (coming soon)
                  _buildSettingRow(
                    icon: Icons.favorite,
                    label: "Favorites behavior",
                    trailing: _comingSoonBadge(),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingRow(
                    icon: Icons.refresh,
                    label: "Reset current session",
                    trailing: _comingSoonBadge(),
                  ),
                  const SizedBox(height: 16),
                  // Performance Mode explanation
                  if (PerformanceService.isIOSWeb) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Performance Mode is recommended for iPhone browsers to prevent crashes.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SofiStudioTheme.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: SofiStudioTheme.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SofiStudioTheme.charcoal,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _comingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Coming soon',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
