import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// iPhone-safe stage image renderer.
/// DreamFlow / Flutter-stable compatible (NO Dart 3 records)
///
/// Supports these sources (first non-null wins):
/// - bytes: raw image bytes
/// - base64: raw base64 string or data URI (data:image/...;base64,XXXX)
/// - url: network image
///
/// Notes:
/// - Avoids DecorationImage paths that can crash on iOS Web CanvasKit when
///   combined with rounded borders. Uses clipped Image.* widgets instead.
/// - Provides graceful decoding with debug logs and safe padding for base64.
class StageImage extends StatefulWidget {
  const StageImage({
    super.key,
    this.bytes,
    this.base64,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
    this.filterQuality = FilterQuality.high,
  });

  final Uint8List? bytes;
  final String? base64;
  final String? url;

  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? semanticLabel;
  final FilterQuality filterQuality;

  @override
  State<StageImage> createState() => _StageImageState();
}

class _StageImageState extends State<StageImage> {
  Uint8List? _bytes;
  bool _decoding = false;
  String? _lastBase64Key;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant StageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged = oldWidget.bytes != widget.bytes ||
        oldWidget.base64 != widget.base64 ||
        oldWidget.url != widget.url;
    if (sourceChanged) _hydrate();
  }

  void _hydrate() {
    // Priority: bytes > base64 > url
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      setState(() {
        _bytes = widget.bytes;
        _decoding = false;
        _lastBase64Key = null;
      });
      return;
    }

    if (widget.base64 != null && widget.base64!.trim().isNotEmpty) {
      final key = widget.base64;
      if (_lastBase64Key == key && _bytes != null) return; // already decoded
      setState(() {
        _decoding = true;
      });
      // Decode on next microtask to keep UI responsive
      Future.microtask(() {
        try {
          final bytes = _decodeBase64(widget.base64!);
          if (!mounted) return;
          setState(() {
            _bytes = bytes;
            _decoding = false;
            _lastBase64Key = key;
          });
        } catch (e) {
          debugPrint('StageImage: Failed to decode base64: $e');
          if (!mounted) return;
          setState(() {
            _bytes = null;
            _decoding = false;
            _lastBase64Key = key;
          });
        }
      });
      return;
    }

    // No bytes or base64; clear local bytes so url/network path is used.
    setState(() {
      _bytes = null;
      _decoding = false;
      _lastBase64Key = null;
    });
  }

  Uint8List _decodeBase64(String input) {
    // Strip data URI prefix if present
    String s = input.trim();
    final dataPrefix = RegExp(r'^data:[^;]+;base64,', caseSensitive: false);
    s = s.replaceFirst(dataPrefix, '');

    // Remove whitespace/newlines
    s = s.replaceAll(RegExp(r'\s+'), '');

    // Fix padding
    final mod = s.length % 4;
    if (mod != 0) {
      final pad = 4 - mod;
      s = s.padRight(s.length + pad, '=');
    }

    try {
      return base64Decode(s);
    } on FormatException catch (e) {
      debugPrint('StageImage: base64 format error, attempting sanitization: $e');
      // Attempt to sanitize non-base64 characters
      final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      return base64Decode(cleaned);
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
  }

  Widget _buildError() {
    return widget.errorWidget ??
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius? br = widget.borderRadius;

    Widget child;
    if (_decoding) {
      child = _buildPlaceholder();
    } else if (_bytes != null && _bytes!.isNotEmpty) {
      child = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
        isAntiAlias: true,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('StageImage: memory image error: $error');
          return _buildError();
        },
      );
    } else if (widget.url != null && widget.url!.isNotEmpty) {
      child = Image.network(
        widget.url!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
        isAntiAlias: true,
        semanticLabel: widget.semanticLabel,
        loadingBuilder: (context, image, progress) {
          if (progress == null) return image;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('StageImage: network image error: $error');
          return _buildError();
        },
      );
    } else {
      // Nothing to show
      child = _buildError();
    }

    // Important: clip the actual image to avoid DecorationImage+border crash paths on iOS Web
    if (br != null) {
      child = ClipRRect(borderRadius: br, child: child);
    }

    return child;
  }
}
