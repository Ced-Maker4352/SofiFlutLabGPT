import 'dart:typed_data';
import 'package:flutter/material.dart';

typedef HistorySelected = void Function(Uint8List bytes);

typedef HistoryDeleted = void Function(Uint8List bytes);

class SofiHistorySheet extends StatefulWidget {
  // Pre-define BorderRadius constants (Flutter Web crash fix)
  static const _radius26 = BorderRadius.vertical(top: Radius.circular(26));
  static const _radius16 = BorderRadius.all(Radius.circular(16));
  static const _radius14 = BorderRadius.all(Radius.circular(14));
  static const _radius999 = BorderRadius.all(Radius.circular(999));
  
final List<Uint8List> history;
final HistorySelected onSelect;
final HistoryDeleted onDelete;

const SofiHistorySheet({
super.key,
required this.history,
required this.onSelect,
required this.onDelete,
});

@override
State<SofiHistorySheet> createState() => _SofiHistorySheetState();
}

class _SofiHistorySheetState extends State<SofiHistorySheet> {
bool _selectionMode = false;
final Set<Uint8List> _selectedItems = {};

void _toggleSelection(Uint8List bytes) {
setState(() {
if (_selectedItems.contains(bytes)) {
_selectedItems.remove(bytes);
if (_selectedItems.isEmpty) _selectionMode = false;
} else {
_selectedItems.add(bytes);
_selectionMode = true;
}
});
}

void _deleteSelected() {
for (final bytes in _selectedItems) {
widget.onDelete(bytes);
}
setState(() {
_selectedItems.clear();
_selectionMode = false;
});
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => Navigator.pop(context), // tap outside closes
child: Container(
color: Colors.black.withValues(alpha: 0.45),
child: GestureDetector(
onTap: () {}, // prevent tap-through
child: DraggableScrollableSheet(
expand: false,
initialChildSize: 0.95,
minChildSize: 0.60,
maxChildSize: 0.95,
builder: (_, controller) {
return Container(
decoration: const BoxDecoration(
color: Colors.white,
borderRadius: SofiHistorySheet._radius26,
),
child: Column(
children: [
const SizedBox(height: 10),
Container(
width: 40,
height: 5,
decoration: const BoxDecoration(
color: Colors.black26,
borderRadius: SofiHistorySheet._radius999,
),
),
const SizedBox(height: 12),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Row(
children: [
if (_selectionMode)
IconButton(
onPressed: () {
setState(() {
_selectionMode = false;
_selectedItems.clear();
});
},
icon: const Icon(Icons.close),
)
else
const SizedBox(width: 48), // Spacer to balance center title
Expanded(
child: Text(
_selectionMode
? "${_selectedItems.length} Selected"
: "History",
textAlign: TextAlign.center,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.w700,
color: Colors.black87,
),
),
),
if (_selectionMode)
IconButton(
onPressed: _deleteSelected,
icon: const Icon(Icons.delete_outline, color: Colors.red),
)
else
IconButton(
onPressed: () {
setState(() {
_selectionMode = true;
});
},
icon: const Icon(Icons.checklist),
),
],
),
),
const SizedBox(height: 12),
Expanded(
child: GridView.builder(
controller: controller,
padding: const EdgeInsets.all(16),
gridDelegate:
const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 3,
mainAxisSpacing: 12,
crossAxisSpacing: 12,
childAspectRatio: 0.75,
),
itemCount: widget.history.length,
itemBuilder: (_, i) {
final bytes = widget.history[i];
final isSelected = _selectedItems.contains(bytes);

return Stack(
children: [
GestureDetector(
onTap: () {
if (_selectionMode) {
_toggleSelection(bytes);
} else {
Navigator.pop(context);
widget.onSelect(bytes);
}
},
onLongPress: () => _toggleSelection(bytes),
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
decoration: BoxDecoration(
borderRadius: SofiHistorySheet._radius16,
border: isSelected
? Border.all(color: Colors.purple, width: 3)
: null,
),
child: ClipRRect(
borderRadius: SofiHistorySheet._radius14,
child: Image.memory(
bytes,
fit: BoxFit.cover,
),
),
),
),
if (_selectionMode)
Positioned(
top: 6,
right: 6,
child: Container(
decoration: BoxDecoration(
color: isSelected ? Colors.purple : Colors.black.withValues(alpha: 0.4),
shape: BoxShape.circle,
border: Border.all(color: Colors.white, width: 2),
),
padding: const EdgeInsets.all(4),
child: isSelected
? const Icon(Icons.check, size: 12, color: Colors.white)
: const SizedBox(width: 12, height: 12),
),
)
else
Positioned(
top: 6,
right: 6,
child: GestureDetector(
onTap: () => widget.onDelete(bytes),
child: Container(
width: 26,
height: 26,
decoration: BoxDecoration(
color: Colors.black.withValues(alpha: 0.65),
shape: BoxShape.circle,
),
child: const Icon(
Icons.delete,
size: 16,
color: Colors.white,
),
),
),
),
],
);
},
),
),
],
),
);
},
),
),
),
);
}
}
