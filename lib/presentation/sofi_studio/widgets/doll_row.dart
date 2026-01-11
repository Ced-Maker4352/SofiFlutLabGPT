// lib/presentation/sofi_studio/widgets/doll_row.dart

import 'package:flutter/material.dart';
import 'package:sofi_test_connect/services/storage_service.dart';
import '../sofi_studio_models.dart';
import '../sofi_studio_theme.dart';
import 'frost_card.dart';

class DollRow extends StatelessWidget {
  final String title;
  final List<SofiDoll> dolls;
  final SofiDoll? selected;
  final ValueChanged<SofiDoll> onSelect;
  final bool premium;

  const DollRow({
    super.key,
    required this.title,
    required this.dolls,
    required this.selected,
    required this.onSelect,
    this.premium = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dolls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            title,
            style: TextStyle(
              color: premium
                  ? SofiStudioTheme.blue
                  : SofiStudioTheme.charcoal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dolls.length,
            itemBuilder: (context, index) {
              final doll = dolls[index];
              final bool isSelected = doll == selected;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelect(doll),
                  child: FrostCard(
                    padding: EdgeInsets.zero,
                    blur: 14,
                    elevation: isSelected ? 12 : 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    borderColor: isSelected
                        ? SofiStudioTheme.blue
                        : Colors.white.withValues(alpha: 0.5),
                    child: Container(
                      width: 70,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            SofiStudioTheme.radiusMedium),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: doll.isStoragePath
                          ? _FirebaseImage(path: doll.thumbPath)
                          : Image.asset(
                              doll.thumbPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => const Center(
                                child: Icon(Icons.broken_image, size: 18),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Helper widget to load images from Firebase Storage
class _FirebaseImage extends StatefulWidget {
  final String path;

  const _FirebaseImage({required this.path});

  @override
  State<_FirebaseImage> createState() => _FirebaseImageState();
}

class _FirebaseImageState extends State<_FirebaseImage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_FirebaseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() => _loading = true);
    try {
      final url = await StorageService.instance.getDownloadUrl(widget.path);
      if (mounted) setState(() => _url = url);
    } catch (e) {
      debugPrint('Failed to load doll image: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_url == null) {
      return const Center(child: Icon(Icons.broken_image, size: 18));
    }
    return Image.network(_url!, fit: BoxFit.cover);
  }
}
