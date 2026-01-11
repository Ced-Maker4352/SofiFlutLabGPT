// lib/presentation/sofi_studio/state_snapshot.dart

import 'dart:typed_data';
import 'sofi_studio_models.dart';

/// Snapshot object holding:
/// – category selections
/// – generated image bytes (optional)
class SofiSnapshot {
final Map<EditCategory, int?> categories;
final Uint8List? imageBytes;

SofiSnapshot({
required this.categories,
required this.imageBytes,
});

/// Deep copy for safety
SofiSnapshot clone() {
return SofiSnapshot(
categories: Map<EditCategory, int?>.from(categories),
imageBytes: imageBytes != null ? Uint8List.fromList(imageBytes!) : null,
);
}
}

/// A stack to store undo states
class SnapshotStack {
final List<SofiSnapshot> _stack = [];

bool get isEmpty => _stack.isEmpty;
bool get isNotEmpty => _stack.isNotEmpty;

/// Push categories-only snapshot
void push(Map<EditCategory, int?> categories) {
final copy = Map<EditCategory, int?>.from(categories);
_stack.add(SofiSnapshot(categories: copy, imageBytes: null));
}

/// Push image snapshot
void pushImage(Uint8List bytes) {
if (_stack.isEmpty) {
// Create empty category map if needed
_stack.add(SofiSnapshot(
categories: {},
imageBytes: Uint8List.fromList(bytes),
));
} else {
_stack.add(SofiSnapshot(
categories: Map<EditCategory, int?>.from(_stack.last.categories),
imageBytes: Uint8List.fromList(bytes),
));
}
}

/// Undo = pop, return the new last
SofiSnapshot undo() {
if (_stack.isEmpty) {
return SofiSnapshot(categories: {}, imageBytes: null);
}

_stack.removeLast();

if (_stack.isEmpty) {
return SofiSnapshot(categories: {}, imageBytes: null);
}

return _stack.last.clone();
}
}
