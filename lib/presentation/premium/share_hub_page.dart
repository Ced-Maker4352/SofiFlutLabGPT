import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareHubPage extends StatefulWidget {
  /// Base64 encoded image to share (optional - shows empty state if null)
  final String? imageBase64;
  
  /// Optional prompt/description for the image
  final String? prompt;

  /// Whether this image was created using a premium feature
  /// Controls rendering of a distinct watermark badge in the bottom-right
  final bool isPremiumImage;

  const ShareHubPage({
    super.key,
    this.imageBase64,
    this.prompt,
    this.isPremiumImage = false,
  });

  @override
  State<ShareHubPage> createState() => _ShareHubPageState();
}

class _ShareHubPageState extends State<ShareHubPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _selectedFrame = 0;
  bool _showWatermark = true;
  bool _isSharing = false;

  static const _frames = [
    _FrameStyle(name: 'None', icon: Icons.crop_free),
    _FrameStyle(name: 'Polaroid', icon: Icons.photo),
    _FrameStyle(name: 'Story', icon: Icons.auto_stories),
    _FrameStyle(name: 'Square', icon: Icons.crop_square),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _shareImage() async {
    if (widget.imageBase64 == null) return;
    
    setState(() => _isSharing = true);
    
    try {
      final bytes = base64Decode(widget.imageBase64!);
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'sofi_creation_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: widget.prompt ?? 'Created with Sofi Studio ✨',
          subject: 'My Sofi Creation',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _downloadImage() async {
    if (widget.imageBase64 == null) return;
    
    // For web, share_plus will handle download via blob URL
    // For mobile, it triggers save to gallery
    await _shareImage();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageBase64 != null;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Share',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0D0D0F)],
          ),
        ),
        child: SafeArea(
          child: hasImage ? _buildShareContent() : _buildEmptyState(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _animController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Image to Share',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create something amazing first,\nthen come back to share it!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          FadeTransition(
            opacity: _animController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animController,
                curve: Curves.easeOut,
              )),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ).createShader(bounds),
                    child: const Text(
                      'Share Your Creation',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show off your style to the world',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Image Preview with Frame
          Center(
            child: FadeTransition(
              opacity: _animController,
              child: _buildImagePreview(),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Frame Selection
          Text(
            'Frame Style',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _frames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _buildFrameOption(index),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Watermark Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.branding_watermark_outlined,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Sofi Watermark',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _showWatermark,
                  onChanged: (v) => setState(() => _showWatermark = v),
                  activeColor: const Color(0xFF667eea),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Share Options
          Text(
            'Share To',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ShareButton(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                gradient: [const Color(0xFF667eea), const Color(0xFF764ba2)],
                onTap: _isSharing ? null : _shareImage,
                isLoading: _isSharing,
              ),
              _ShareButton(
                icon: Icons.camera_alt_rounded,
                label: 'Stories',
                gradient: [const Color(0xFFf093fb), const Color(0xFFf5576c)],
                onTap: _shareImage,
              ),
              _ShareButton(
                icon: Icons.play_circle_filled_rounded,
                label: 'TikTok',
                gradient: [const Color(0xFF00f2fe), const Color(0xFF4facfe)],
                onTap: _shareImage,
              ),
              _ShareButton(
                icon: Icons.download_rounded,
                label: 'Save',
                gradient: [const Color(0xFF11998e), const Color(0xFF38ef7d)],
                onTap: _downloadImage,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Main Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSharing ? null : _shareImage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSharing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded),
                        SizedBox(width: 8),
                        Text(
                          'Share Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          if (widget.prompt != null && widget.prompt!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Style Used',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.prompt!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final bytes = base64Decode(widget.imageBase64!);
    
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
    
    // Apply frame style
    switch (_selectedFrame) {
      case 1: // Polaroid
        imageWidget = Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: imageWidget,
        );
        break;
      case 2: // Story (9:16)
        imageWidget = AspectRatio(
          aspectRatio: 9 / 16,
          child: imageWidget,
        );
        break;
      case 3: // Square
        imageWidget = AspectRatio(
          aspectRatio: 1,
          child: imageWidget,
        );
        break;
      default: // None - original
        break;
    }
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          imageWidget,
          if (_showWatermark)
            Positioned(
              bottom: _selectedFrame == 1 ? 50 : 16,
              right: _selectedFrame == 1 ? 20 : 16,
              child: _WatermarkBadge(isPremium: widget.isPremiumImage),
            ),
        ],
      ),
    );
  }

  Widget _buildFrameOption(int index) {
    final frame = _frames[index];
    final isSelected = _selectedFrame == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFrame = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF667eea).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF667eea)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              frame.icon,
              color: isSelected
                  ? const Color(0xFF667eea)
                  : Colors.white.withValues(alpha: 0.6),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              frame.name,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatermarkBadge extends StatelessWidget {
  final bool isPremium;
  const _WatermarkBadge({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    // Keep same position/size feel as the existing watermark
    // Distinguish premium with a subtle gradient pill and a star icon
    if (!isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 12, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              'Sofi Studio',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9B59B6), // Purple
            Color(0xFFE91E63), // Pink
            Color(0xFFFF9800), // Orange/Gold
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 6),
          const Text(
            'Sofi Studio • Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameStyle {
  final String name;
  final IconData icon;
  
  const _FrameStyle({required this.name, required this.icon});
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
