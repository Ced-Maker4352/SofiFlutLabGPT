import 'package:flutter/material.dart';
import 'package:sofi_test_connect/presentation/mood/mood_mode.dart';
import 'package:sofi_test_connect/constants/mood_icons.dart';
import 'package:sofi_test_connect/services/storage_service.dart';

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

return SizedBox(
height: 90,
child: ListView.separated(
scrollDirection: Axis.horizontal,
padding: const EdgeInsets.symmetric(horizontal: 16),
itemCount: modes.length,
separatorBuilder: (_, __) => const SizedBox(width: 12),
itemBuilder: (context, index) {
final mode = modes[index];
final isSelected = mode == selected;

return InkWell(
borderRadius: BorderRadius.circular(16),
onTap: () => onSelect(mode),
child: AnimatedScale(
scale: isSelected ? 1.08 : 1.0,
duration: const Duration(milliseconds: 160),
curve: Curves.easeOut,
child: Stack(
children: [
AnimatedContainer(
duration: const Duration(milliseconds: 180),
width: 72,
height: 72,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: isSelected
? Colors.white
: Colors.white.withValues(alpha: 0.3),
width: isSelected ? 2 : 1,
),
boxShadow: isSelected
? [
BoxShadow(
color: Colors.white.withValues(alpha: 0.35),
blurRadius: 14,
spreadRadius: 1,
)
]
: [],
),
child: ClipRRect(
borderRadius: BorderRadius.circular(14),
child: _FirebaseMoodIcon(
firebasePath: MoodIcons.firebasePath[mode]!,
fit: BoxFit.cover,
),
),
),
if (mode.isPremium)
const Positioned(
top: 6,
right: 6,
child: Icon(
Icons.lock,
size: 16,
color: Colors.white,
),
),
],
),
),
);
},
),
);
}
}

/// Internal widget to load Firebase image asynchronously
class _FirebaseMoodIcon extends StatefulWidget {
final String firebasePath;
final BoxFit fit;

const _FirebaseMoodIcon({
required this.firebasePath,
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
if (widget.firebasePath != oldWidget.firebasePath) _loadImage();
}

Future<void> _loadImage() async {
setState(() {
_loading = true;
_error = false;
});

try {
final url = await StorageService.instance.getDownloadUrlSafe(widget.firebasePath);
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
return Container(
color: Colors.grey[800],
child: const Icon(Icons.broken_image, size: 18, color: Colors.white54),
);
}

return Image.network(
_url!,
fit: widget.fit,
errorBuilder: (_, __, ___) => Container(
color: Colors.grey[800],
child: const Icon(Icons.broken_image, size: 18, color: Colors.white54),
),
);
}
}
