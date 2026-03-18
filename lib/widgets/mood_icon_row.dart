import 'package:flutter/material.dart';
import 'package:sofi_test_connect/presentation/mood/mood_mode.dart';
import 'package:sofi_test_connect/constants/mood_icons.dart';
import 'package:sofi_test_connect/services/storage_service.dart';
import 'package:sofi_test_connect/services/premium_service.dart';

/// Drop-in icon row for mood selection (uses Firebase images from Premium Studio)
class MoodIconRow extends StatelessWidget {
  final MoodMode selected;
  final void Function(MoodMode) onSelect;

  const MoodIconRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final modes = MoodMode.values;

    final itemWidth = MediaQuery.of(context).size.width / modes.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: modes.map((mode) {
        final isSelected = mode == selected;

        return InkWell(
          onTap: () => onSelect(mode),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: itemWidth,
                height: itemWidth, // Kept square
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.1),
                    width: isSelected ? 3 : 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _FirebaseMoodIcon(
                    mode: mode,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: PremiumService(),
                builder: (context, _) {
                  final isPremiumUser = PremiumService().isPremium;
                  if (!mode.isPremium || isPremiumUser) return const SizedBox.shrink();
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Internal widget to load Firebase image asynchronously
class _FirebaseMoodIcon extends StatefulWidget {
  final MoodMode mode;
  final BoxFit fit;

  const _FirebaseMoodIcon({
    required this.mode,
    this.fit = BoxFit.cover,
  });

  @override
  State<_FirebaseMoodIcon> createState() => _FirebaseMoodIconState();
}

class _FirebaseMoodIconState extends State<_FirebaseMoodIcon> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_FirebaseMoodIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final path = MoodIcons.firebasePath[widget.mode];
      if (path == null) throw Exception("No Firebase path for mode");
      final url = await StorageService.instance.getDownloadUrlSafe(path);
      if (!mounted) return;
      setState(() {
        _url = url;
        _error = (url == null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      );
    }

    if (_error || _url == null) {
      return Image.asset(
        MoodIcons.localAssetPath[widget.mode]!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.broken_image, size: 18, color: Colors.white54),
        ),
      );
    }

    return Image.network(
      _url!,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => Image.asset(
        MoodIcons.localAssetPath[widget.mode]!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.broken_image, size: 18, color: Colors.white54),
        ),
      ),
    );
  }
}
