import 'package:flutter/material.dart';
import 'package:sofi_test_connect/data/theme_presets_data.dart';
import 'package:sofi_test_connect/models/theme_presets.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_style_presets.dart';
import 'package:sofi_test_connect/services/storage_service.dart';

class DiscoverPage extends StatelessWidget {
  final void Function(ThemePreset theme)? onThemeSelected;
  final void Function(Map<String, dynamic> stylePreset)? onStyleSelected;
  
  const DiscoverPage({
    super.key,
    this.onThemeSelected,
    this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final freeThemes = themePresets.where((t) => !t.isPremium).toList();
    final premiumThemes = themePresets.where((t) => t.isPremium).toList();
    final stylePresets = SofiStylePresets.presets;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F4),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFFF8F6F4),
            elevation: 0,
            title: const Text(
              'Discover',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Colors.black,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black),
                onPressed: () {},
              ),
            ],
          ),
          
          // Featured Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _FeaturedBanner(
                theme: freeThemes.isNotEmpty ? freeThemes.first : null,
                onTap: () {
                  if (freeThemes.isNotEmpty && onThemeSelected != null) {
                    onThemeSelected!(freeThemes.first);
                  }
                },
              ),
            ),
          ),
          
          // Style Presets Section
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Quick Styles',
              subtitle: 'One-tap outfit transformations',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: stylePresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _StylePresetChip(
                  preset: stylePresets[i],
                  onTap: () => onStyleSelected?.call(stylePresets[i]),
                ),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          
          // Free Themes Section
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Art Styles',
              subtitle: 'Transform your look',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ThemeCard(
                  theme: freeThemes[i],
                  onTap: () => onThemeSelected?.call(freeThemes[i]),
                ),
                childCount: freeThemes.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          
          // Premium Themes Section
          if (premiumThemes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Premium Collection',
                subtitle: 'Exclusive styles',
                isPremium: true,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ThemeCard(
                    theme: premiumThemes[i],
                    isPremium: true,
                    onTap: () => onThemeSelected?.call(premiumThemes[i]),
                  ),
                  childCount: premiumThemes.length,
                ),
              ),
            ),
          ],
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

/// Featured banner at top
class _FeaturedBanner extends StatelessWidget {
  final ThemePreset? theme;
  final VoidCallback? onTap;
  
  const _FeaturedBanner({this.theme, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8B4E0), Color(0xFFB4D4E8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              right: 40,
              top: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Content - tightly constrained to avoid overflow
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Adjust spacing based on available height
                    final availableHeight = constraints.maxHeight;
                    final isTight = availableHeight < 150;
                    final isVeryTight = availableHeight < 140;
                    
                    final titleSize = isVeryTight ? 18.0 : (isTight ? 20.0 : 24.0);
                    final subtitleSize = isVeryTight ? 11.0 : (isTight ? 12.0 : 13.0);
                    final ctaVPad = isVeryTight ? 4.0 : (isTight ? 5.0 : 6.0);
                    final chipVPad = isVeryTight ? 2.0 : (isTight ? 3.0 : 4.0);
                    final verticalSpacing = isVeryTight ? 4.0 : (isTight ? 6.0 : 8.0);
                    final midSpacing = isVeryTight ? 6.0 : (isTight ? 8.0 : 10.0);

                    // Ensure the banner content never overflows by scaling down if needed
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: chipVPad),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 12, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Featured',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: verticalSpacing),
                          Text(
                            theme?.label ?? 'Explore Styles',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            theme?.description ?? 'Discover new looks',
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: midSpacing),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: ctaVPad),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Try Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with title and subtitle
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isPremium;
  
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFB700)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Style preset chip (Quick Styles)
class _StylePresetChip extends StatelessWidget {
  final Map<String, dynamic> preset;
  final VoidCallback? onTap;
  
  const _StylePresetChip({required this.preset, this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = preset['icon'] as String? ?? '';
    final label = preset['label'] as String? ?? 'Style';
    final key = (preset['key'] as String? ?? label).toString().toLowerCase();
    
    // Generate a color based on label
    final colors = _getColorsForStyle(key, label);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getIconForStyle(icon, key, label),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _getIconForStyle(String icon, String key, String label) {
    // Use Material icons instead of emoji characters
    IconData iconData;
    switch (key) {
      case 'clean_girl':
      case 'clean girl':
      case 'clean girl neutral set':
        iconData = Icons.spa;
        break;
      case 'y2k':
      case 'y2k style':
      case 'pastel y2k set':
        iconData = Icons.star;
        break;
      case 'street_minimal':
      case 'street minimal':
        iconData = Icons.location_city;
        break;
      case 'soft_girl':
      case 'soft girl':
      case 'soft girl aesthetic':
        iconData = Icons.favorite;
        break;
      case 'academia':
      case 'academia aesthetic':
        iconData = Icons.menu_book;
        break;
      default:
        iconData = Icons.auto_awesome;
    }
    return Icon(iconData, size: 32, color: Colors.white);
  }
  
  List<Color> _getColorsForStyle(String key, String label) {
    final k = key.isNotEmpty ? key : label.toLowerCase();
    switch (k) {
      case 'clean_girl':
      case 'clean girl':
      case 'clean girl neutral set':
        return [const Color(0xFFF5E6D3), const Color(0xFFE8D4C4)];
      case 'y2k':
      case 'y2k style':
      case 'pastel y2k set':
        return [const Color(0xFF7DD3FC), const Color(0xFFC4B5FD)];
      case 'street_minimal':
      case 'street minimal':
        return [const Color(0xFF374151), const Color(0xFF1F2937)];
      case 'soft_girl':
      case 'soft girl':
      case 'soft girl aesthetic':
        return [const Color(0xFFFBCFE8), const Color(0xFFF9A8D4)];
      case 'academia':
      case 'academia aesthetic':
        return [const Color(0xFF92400E), const Color(0xFF78350F)];
      default:
        return [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)];
    }
  }
}

/// Theme card for grid - uses Firebase Storage images
class _ThemeCard extends StatelessWidget {
  final ThemePreset theme;
  final bool isPremium;
  final VoidCallback? onTap;
  
  const _ThemeCard({
    required this.theme,
    this.isPremium = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (theme.assetPath != null)
                    _FirebaseThemeImage(
                      path: theme.assetPath!,
                      localAssetPath: theme.localAssetPath,
                      fallbackColor: _getColorForTheme(theme.id),
                      fallbackIcon: _getIconForTheme(theme.id),
                    )
                  else
                    Container(
                      color: _getColorForTheme(theme.id),
                      child: Icon(
                        _getIconForTheme(theme.id),
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 48,
                      ),
                    ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Premium badge
                  if (isPremium)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFB700)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Variants count
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${theme.variants.length} variants',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        theme.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
  
  Color _getColorForTheme(String id) {
    switch (id) {
      case 'pixar':
        return const Color(0xFF5D7CE8);
      case 'anime':
        return const Color(0xFFE85D9F);
      case 'comic':
        return const Color(0xFFE8A05D);
      case 'superhero':
        return const Color(0xFF5DE8A0);
      case 'fashion':
        return const Color(0xFFA05DE8);
      case 'fantasy':
        return const Color(0xFF5DC8E8);
      case 'scifi':
        return const Color(0xFF5DE87A);
      case 'realistic':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
  
  IconData _getIconForTheme(String id) {
    switch (id) {
      case 'pixar':
        return Icons.movie_creation;
      case 'anime':
        return Icons.face;
      case 'comic':
        return Icons.auto_stories;
      case 'superhero':
        return Icons.flash_on;
      case 'fashion':
        return Icons.checkroom;
      case 'fantasy':
        return Icons.auto_fix_high;
      case 'scifi':
        return Icons.rocket_launch;
      case 'realistic':
        return Icons.photo_camera;
      default:
        return Icons.palette;
    }
  }
}

/// Firebase image loader for theme thumbnails
class _FirebaseThemeImage extends StatefulWidget {
  final String path;
  final String? localAssetPath;
  final Color fallbackColor;
  final IconData fallbackIcon;
  
  const _FirebaseThemeImage({
    required this.path,
    this.localAssetPath,
    required this.fallbackColor,
    required this.fallbackIcon,
  });

  @override
  State<_FirebaseThemeImage> createState() => _FirebaseThemeImageState();
}

class _FirebaseThemeImageState extends State<_FirebaseThemeImage> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_FirebaseThemeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final url = await StorageService.instance.getDownloadUrlSafe(widget.path);
      if (mounted) {
        setState(() {
          _url = url;
          if (url == null) _error = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: widget.fallbackColor,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    if (_error || _url == null) {
      // Try local asset fallback if provided
      if (widget.localAssetPath != null) {
        return Image.asset(
          widget.localAssetPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: widget.fallbackColor,
            child: Icon(
              widget.fallbackIcon,
              color: Colors.white.withValues(alpha: 0.5),
              size: 48,
            ),
          ),
        );
      }
      return Container(
        color: widget.fallbackColor,
        child: Icon(
          widget.fallbackIcon,
          color: Colors.white.withValues(alpha: 0.5),
          size: 48,
        ),
      );
    }

    return Image.network(
      _url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: widget.fallbackColor,
        child: Icon(
          widget.fallbackIcon,
          color: Colors.white.withValues(alpha: 0.5),
          size: 48,
        ),
      ),
    );
  }
}
