// lib/presentation/sofi_studio/widgets/sofi_grid_tile.dart
import 'package:flutter/material.dart';

class SofiGridTile extends StatelessWidget {
final Widget child;
final String label;
final bool isSelected;
final VoidCallback onTap;

const SofiGridTile({
super.key,
required this.child,
required this.label,
required this.isSelected,
required this.onTap,
});

@override
Widget build(BuildContext context) {
final baseColor = const Color(0xFFE6E6E6);

return InkWell(
borderRadius: BorderRadius.circular(18),
onTap: onTap,
child: Column(
children: [
Expanded(
child: Container(
decoration: BoxDecoration(
color: baseColor,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
width: isSelected ? 2 : 0,
),
),
clipBehavior: Clip.antiAlias,
child: Center(child: child),
),
),
const SizedBox(height: 4),
Text(
label,
textAlign: TextAlign.center,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 11,
),
),
],
),
);
}
}
