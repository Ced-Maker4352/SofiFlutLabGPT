import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_models.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_studio_theme.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_prompt_data.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/sofi_male_prompt_data.dart';
import 'package:sofi_test_connect/presentation/premium/paywall_sheet.dart';
import 'package:sofi_test_connect/services/storage_service.dart';
import 'package:sofi_test_connect/services/premium_service.dart';
import 'package:sofi_test_connect/services/performance_service.dart';
import 'package:sofi_test_connect/services/user_preferences_service.dart';

/// Apple Maps-style bottom drawer with peek / mid / full snapping.
/// Optimized for iPhone with proper safe area handling.
/// Loads actual prompt data from SofiPromptData with Firebase thumbnails.
/// Includes doll picker and premium feature gating.
class SofiBottomDrawer extends StatefulWidget {
  final VoidCallback onGenerate;
  final void Function(EditCategory category, int option) onCategorySelected;
  final List<SofiDoll> baseDolls;
  final List<SofiDoll> premiumDolls;
  final SofiDoll? currentDoll;
  final void Function(SofiDoll doll) onDollSelected;

  // Caption props
  final String captionText;
  final ValueChanged<String>? onCaptionChanged;
  final String captionFont;
  final ValueChanged<String>? onCaptionFontChanged;
  final Color captionColor;
  final ValueChanged<Color>? onCaptionColorChanged;
  final double captionY;
  final ValueChanged<double>? onCaptionYChanged;
  final List<String> captionFonts;

  const SofiBottomDrawer({
    super.key,
    required this.onGenerate,
    required this.onCategorySelected,
    this.baseDolls = const [],
    this.premiumDolls = const [],
    this.currentDoll,
    required this.onDollSelected,
    // Caption props
    this.captionText = '',
    this.onCaptionChanged,
    this.captionFont = 'Fredoka',
    this.onCaptionFontChanged,
    this.captionColor = Colors.white,
    this.onCaptionColorChanged,
    this.captionY = 0.85,
    this.onCaptionYChanged,
    this.captionFonts = const [],
    this.initialCategory,
  });

  final EditCategory? initialCategory;

  @override
  State<SofiBottomDrawer> createState() => _SofiBottomDrawerState();
}

class _SofiBottomDrawerState extends State<SofiBottomDrawer> {
  // Snap heights as fraction of screen height
  static const double _peekFraction = 0.15;
  static const double _midFraction = 0.45;
  static const double _fullFraction = 0.85;

  // Start at 3/4 open as requested (between mid and full)
  double _currentFraction = 0.75;

  EditCategory _selectedCategory = EditCategory.fullOutfit;
  
  // Cache for Firebase thumbnail URLs
  final Map<String, String> _thumbnailUrlCache = {};
  
  // Premium status
  bool _isPremium = false;

  late final TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? EditCategory.fullOutfit;
    if (_selectedCategory == EditCategory.caption) {
      _currentFraction = _midFraction;
    }
    _captionController = TextEditingController(text: widget.captionText);
    // Listen for future subscription changes to keep UI in sync
    PremiumService().addListener(_onPremiumChanged);
    // Listen for gender changes
    UserPreferencesService.instance.addListener(_onGenderChanged);
  }
  
  @override
  void dispose() {
    PremiumService().removeListener(_onPremiumChanged);
    UserPreferencesService.instance.removeListener(_onGenderChanged);
    _captionController.dispose();
    super.dispose();
  }
  
  void _onPremiumChanged() {
    final service = PremiumService();
    final newValue = service.isPremium;
    if (newValue != _isPremium && mounted) {
      setState(() => _isPremium = newValue);
    }
  }

  void _onGenderChanged() {
    if (mounted) setState(() {});
  }
  
  Future<void> _checkPremiumStatus() async {
    final service = PremiumService();
    await service.initialize();
    if (mounted) {
      setState(() => _isPremium = service.isPremium);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final delta = -details.delta.dy / screenHeight;
    setState(() {
      _currentFraction = (_currentFraction + delta).clamp(0.1, 0.9);
    });
  }

  void _onDragStart(DragStartDetails details) {
    // Capture start for future gesture improvements
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    double target;

    // If flicking fast, snap in flick direction
    if (velocity < -500) {
      // Flick up
      if (_currentFraction < _midFraction) {
        target = _midFraction;
      } else {
        target = _fullFraction;
      }
    } else if (velocity > 500) {
      // Flick down
      if (_currentFraction > _midFraction) {
        target = _midFraction;
      } else {
        target = _peekFraction;
      }
    } else {
      // Snap to nearest
      final distPeek = (_currentFraction - _peekFraction).abs();
      final distMid = (_currentFraction - _midFraction).abs();
      final distFull = (_currentFraction - _fullFraction).abs();

      if (distPeek <= distMid && distPeek <= distFull) {
        target = _peekFraction;
      } else if (distMid <= distFull) {
        target = _midFraction;
      } else {
        target = _fullFraction;
      }
    }

    if (!mounted) return;
    setState(() {
      _currentFraction = target;
    });
  }
  
  /// Get the Firebase Storage path for a category thumbnail
  String? _getThumbnailPath(EditCategory category, int index) {
    final isMale = UserPreferencesService.instance.isMaleMode;
    final num = (index + 1).toString().padLeft(2, '0');
    final folder = isMale ? 'male/' : '';

    switch (category) {
      case EditCategory.fullOutfit:
        return isMale 
          ? 'images/male/outfits/male_outfit_$num.png'
          : 'images/full outfit/full_outfit_$num.jpg';
      case EditCategory.hair:
        return isMale
          ? 'images/male/hair/hair_$num.png'
          : 'images/hair/hair_$num.jpg';
      case EditCategory.top:
        return isMale
          ? 'images/male/top/top_$num.png'
          : 'images/top/top_$num.jpg';
      case EditCategory.bottom:
        return isMale
          ? 'images/male/bottom/bottom_$num.png'
          : 'images/bottom/bottom_$num.jpg';
      case EditCategory.shoes:
        return isMale
          ? 'images/male/shoes/shoes_$num.png'
          : 'images/shoes/shoes_$num.jpg';
      case EditCategory.accessories:
        return 'images/accessories/accessories_$num.jpg';
      case EditCategory.hats:
        return 'images/hats/hats_$num.jpg';
      case EditCategory.jewelry:
        return 'images/jewelry/jewelry_$num.jpg';
      case EditCategory.glasses:
        return 'images/glasses/glasses_$num.jpg';
      case EditCategory.poses:
        return 'images/poses/pose_$num.jpg';
      case EditCategory.background:
        return 'images/background/background_$num.jpg';
      case EditCategory.caption:
        return null;
    }
  }

  List<dynamic> _getOptionsForCategory(EditCategory category) {
    final isMale = UserPreferencesService.instance.isMaleMode;
    if (isMale) {
      switch (category) {
        case EditCategory.fullOutfit: return SofiMalePromptData.fullOutfits;
        case EditCategory.hair: return SofiMalePromptData.hair;
        case EditCategory.top: return SofiMalePromptData.tops;
        case EditCategory.bottom: return SofiMalePromptData.bottoms;
        case EditCategory.shoes: return SofiMalePromptData.shoes;
        default: break; // Fall through to standard data for others
      }
    }

    switch (category) {
      case EditCategory.fullOutfit: return SofiPromptData.fullOutfits;
      case EditCategory.hair: return SofiPromptData.hair;
      case EditCategory.top: return SofiPromptData.tops;
      case EditCategory.bottom: return SofiPromptData.bottoms;
      case EditCategory.shoes: return SofiPromptData.shoes;
      case EditCategory.accessories: return SofiPromptData.accessories;
      case EditCategory.hats: return SofiPromptData.hats;
      case EditCategory.jewelry: return SofiPromptData.jewelry;
      case EditCategory.glasses: return SofiPromptData.glasses;
      case EditCategory.poses: return SofiPromptData.poses;
      case EditCategory.background: return SofiPromptData.backgrounds;
      case EditCategory.caption: return [];
    }
  }
  
  /// Check if category is premium-locked (entirely)
  bool _isCategoryLocked(EditCategory category) {
    // Some categories might be entirely premium (e.g., Poses)
    // but others have mixed free/premium items.
    // If ANY item in the category is free, the category itself is NOT locked.
    if (category == EditCategory.poses) return !_isPremium;
    return false; // Categories like hair/top have free items at the start
  }

  /// Check if a specific option in a category is locked
  bool _isOptionLocked(EditCategory category, int optionIndex) {
    if (_isPremium) return false;
    // index is 1-based in the UI logic, but SofiPromptData.isPremiumItem expects 0-based
    return SofiPromptData.isPremiumItem(category, optionIndex - 1);
  }
  
  /// Handle category selection with premium check
  void _onCategoryTap(EditCategory category) {
    if (_isCategoryLocked(category)) {
      // Show paywall for premium categories
      PaywallSheet.show(context, message: 'Unlock ${category.prettyName} with Premium!');
      return;
    }
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      // Adjust height for better caption visibility
      if (category == EditCategory.caption) {
        _currentFraction = _midFraction;
      }
    });
  }
  
  /// Handle option selection with premium check for premium items
  void _onOptionTap(int optionIndex) {
    if (_isOptionLocked(_selectedCategory, optionIndex)) {
      PaywallSheet.show(context, message: 'Unlock this ${_selectedCategory.prettyName} style with Premium!');
      return;
    }
    widget.onCategorySelected(_selectedCategory, optionIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Use PerformanceService to determine if we should disable heavy effects
    final disableEffects = PerformanceService.instance.shouldDisableHeavyEffects;
    final screenHeight = MediaQuery.of(context).size.height;
    final drawerHeight = screenHeight * _currentFraction;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // In performance mode: skip blur and shadows entirely
    if (disableEffects) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: drawerHeight,
        decoration: const BoxDecoration(
          color: SofiStudioTheme.charcoal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _buildDrawerContent(bottomPadding),
      );
    }

    // Full effects mode
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: drawerHeight,
      decoration: BoxDecoration(
        color: SofiStudioTheme.charcoal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: _buildDrawerContent(bottomPadding),
        ),
      ),
    );
  }
  
  Widget _buildDrawerContent(double bottomPadding) {
    // Apple-safe pattern: fixed handle + Expanded scrollable content
    return Column(children: [
      // Drag handle with drag gestures
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: GestureDetector(
              onLongPress: () async {
                await PremiumService().debugClearPremium();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DEBUG: Premium Status Cleared')),
                  );
                }
              },
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Generate button
              Opacity(
                opacity: 0.5,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: widget.onGenerate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SofiStudioTheme.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 4,
                    ),
                    child: const Text('Generate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              // Doll Picker Section
              if (widget.baseDolls.isNotEmpty || widget.premiumDolls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDollPicker(),
              ],
              const SizedBox(height: 8),
              // Category chips row
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  itemCount: EditCategory.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = EditCategory.values[index];
                    final isSelected = cat == _selectedCategory;
                    final isLocked = _isCategoryLocked(cat);
                    return GestureDetector(
                      onTap: () => _onCategoryTap(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? SofiStudioTheme.purple : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? SofiStudioTheme.purple
                                : isLocked
                                    ? Colors.amber.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat.prettyName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                            if (isLocked) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.lock, size: 14, color: Colors.amber),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Options grid (non-scrollable, lets outer scroll handle extra height)
              _buildCategoryOptions(),
            ],
          ),
        ),
      ),
    ]);
  }
  
  /// Build the doll picker section
  Widget _buildDollPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Base Dolls Row
        if (widget.baseDolls.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Choose Your Character',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.baseDolls.length,
              itemBuilder: (context, index) {
                final doll = widget.baseDolls[index];
                final isSelected = widget.currentDoll?.id == doll.id;
                return _buildDollTile(doll, isSelected, false);
              },
            ),
          ),
        ],
        // Premium Dolls Row
        if (widget.premiumDolls.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Premium Characters',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 14, color: Colors.amber),
              ],
            ),
          ),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.premiumDolls.length,
              itemBuilder: (context, index) {
                final doll = widget.premiumDolls[index];
                final isSelected = widget.currentDoll?.id == doll.id;
                return _buildDollTile(doll, isSelected, true);
              },
            ),
          ),
        ],
      ],
    );
  }
  
  /// Build individual doll tile
  Widget _buildDollTile(SofiDoll doll, bool isSelected, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          debugPrint('[SofiBottomDrawer] Doll tapped: ${doll.id}, isPremium: $isPremium, _isPremium: $_isPremium');
          // Premium dolls require premium or show paywall
          if (isPremium && !_isPremium) {
            PaywallSheet.show(context, message: 'Unlock Premium Characters!');
            return;
          }
          debugPrint('[SofiBottomDrawer] Calling onDollSelected...');
          widget.onDollSelected(doll);
        },
        child: Container(
          width: 56,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? SofiStudioTheme.purple 
                  : isPremium 
                      ? Colors.amber.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: SofiStudioTheme.purple.withOpacity(0.4),
                blurRadius: 8,
              ),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                doll.isStoragePath
                    ? _DollFirebaseImage(path: doll.thumbPath, urlCache: _thumbnailUrlCache)
                    : Image.asset(
                        doll.thumbPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: SofiStudioTheme.purple.withOpacity(0.3),
                          child: const Icon(Icons.person, color: Colors.white54),
                        ),
                      ),
                // Premium lock overlay
                if (isPremium && !_isPremium)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Icon(Icons.lock, color: Colors.amber, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOptions() {
    final options = _getOptionsForCategory(_selectedCategory);

    if (_selectedCategory == EditCategory.caption) {
      return _buildCaptionEditor();
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      // Important: let the parent SingleChildScrollView handle scrolling
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        // Pass 1-based index as expected by _getPrompt in sofi_studio_page.dart
        final optionIndex = index + 1;
        
        // Check if THIS specific option is locked
        final isOptionLocked = _isOptionLocked(_selectedCategory, optionIndex);
        
        // Get thumbnail path for this category
        final thumbPath = _getThumbnailPath(_selectedCategory, index);
        
        // Get label
        String label;
        if (_selectedCategory == EditCategory.fullOutfit && option is Map<String, dynamic>) {
          label = option['label'] as String? ?? 'Outfit $optionIndex';
        } else if (option is String) {
          label = _extractLabel(option);
        } else {
          label = 'Option $optionIndex';
        }
        
        return _buildOptionTile(
          label: label,
          thumbPath: thumbPath,
          optionIndex: optionIndex,
          isLocked: isOptionLocked,
        );
      },
    );
  }
  
  Widget _buildOptionTile({
    required String label,
    required String? thumbPath,
    required int optionIndex,
    required bool isLocked,
  }) {
    return GestureDetector(
      onTap: () => _onOptionTap(optionIndex),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail area
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: thumbPath != null
                        ? _FirebaseThumbnail(
                            path: thumbPath,
                            urlCache: _thumbnailUrlCache,
                            onUrlLoaded: (url) {
                              _thumbnailUrlCache[thumbPath] = url;
                            },
                          )
                        : Container(
                            color: SofiStudioTheme.purple.withOpacity(0.3),
                            child: const Icon(
                              Icons.checkroom,
                              color: Colors.white54,
                              size: 32,
                            ),
                          ),
                  ),
                ),
                // Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            // Lock overlay for premium categories
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock, color: Colors.amber, size: 24),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Extract a short label from a prompt string for display
  String _extractLabel(String prompt) {
    // Remove common prefixes like "background:"
    var clean = prompt
        .replaceAll(RegExp(r'^(background|hair|top|bottom|shoes|accessories|hat|glasses|jewelry|pose):\s*', caseSensitive: false), '')
        .trim();
    
    // Capitalize first letter
    if (clean.isNotEmpty) {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }
    
    // Truncate if too long
    if (clean.length > 22) {
      clean = '${clean.substring(0, 19)}...';
    }
    
    return clean;
  }

  Widget _buildCaptionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text Input
        const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _captionController,
          autofocus: true,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Type your message...',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: widget.captionText.isNotEmpty ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _captionController.clear();
                widget.onCaptionChanged?.call('');
              },
            ) : null,
          ),
          onChanged: (val) => widget.onCaptionChanged?.call(val),
        ),
        const SizedBox(height: 20),
        
        // Font Selection
        const Text('Font Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.captionFonts.length,
            itemBuilder: (context, index) {
              final f = widget.captionFonts[index];
              final isSelected = f == widget.captionFont;
              return GestureDetector(
                onTap: () => widget.onCaptionFontChanged?.call(f),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? SofiStudioTheme.purple : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? SofiStudioTheme.purple : Colors.grey[300]!, width: 2),
                    boxShadow: isSelected ? SofiStudioTheme.softShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('Abc', style: GoogleFonts.getFont(f, color: isSelected ? Colors.white : Colors.black, fontSize: 18)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Color Selection
        const Text('Text Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Colors.white, Colors.black, SofiStudioTheme.yellow, Colors.pinkAccent, 
              Colors.cyanAccent, Colors.limeAccent, Colors.orangeAccent, Colors.purpleAccent
            ].map((c) {
              final isSelected = c.value == widget.captionColor.value;
              return GestureDetector(
                onTap: () => widget.onCaptionColorChanged?.call(c),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? SofiStudioTheme.purple : Colors.grey[300]!, width: isSelected ? 3 : 1),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Position Selection
        const Text('Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            _posBtn('Top', 0.1),
            const SizedBox(width: 8),
            _posBtn('Middle', 0.5),
            const SizedBox(width: 8),
            _posBtn('Bottom', 0.85),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _posBtn(String label, double y) {
    final isSelected = (widget.captionY - y).abs() < 0.01;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => widget.onCaptionYChanged?.call(y),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? SofiStudioTheme.purple : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? SofiStudioTheme.purple : Colors.grey[300]!)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Widget to load and display a thumbnail from Firebase Storage.
/// 
/// LAZY LOADING (B approach): Shows a placeholder until it becomes visible on screen,
/// then loads the actual image. This dramatically reduces memory pressure on iOS Safari.
class _FirebaseThumbnail extends StatefulWidget {
  final String path;
  final Map<String, String> urlCache;
  final void Function(String url)? onUrlLoaded;

  const _FirebaseThumbnail({
    required this.path,
    required this.urlCache,
    this.onUrlLoaded,
  });

  @override
  State<_FirebaseThumbnail> createState() => _FirebaseThumbnailState();
}

class _FirebaseThumbnailState extends State<_FirebaseThumbnail> {
  String? _url;
  bool _loading = false; // Start as NOT loading (lazy)
  bool _error = false;
  bool _hasTriggeredLoad = false; // Track if we've started loading

  @override
  void initState() {
    super.initState();
    // Check cache immediately - if cached, show right away
    if (widget.urlCache.containsKey(widget.path)) {
      _url = widget.urlCache[widget.path];
    }
  }

  @override
  void didUpdateWidget(_FirebaseThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _hasTriggeredLoad = false;
      _url = widget.urlCache.containsKey(widget.path) 
          ? widget.urlCache[widget.path] 
          : null;
      _loading = false;
      _error = false;
    }
  }

  /// Called when the widget becomes visible on screen
  void _triggerLazyLoad() {
    if (_hasTriggeredLoad || _url != null) return;
    _hasTriggeredLoad = true;
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    // Check cache first
    if (widget.urlCache.containsKey(widget.path)) {
      if (mounted) {
        setState(() {
          _url = widget.urlCache[widget.path];
          _loading = false;
          _error = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      // Use safe method to handle fallbacks
      final url = await StorageService.instance.getDownloadUrlSafe(widget.path);
      if (mounted) {
        if (url != null) {
          setState(() {
            _url = url;
            _loading = false;
          });
          widget.onUrlLoaded?.call(url);
        } else {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
      }
    } catch (e) {
      debugPrint('[FirebaseThumbnail] Failed to load ${widget.path}: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use VisibilityDetector pattern via LayoutBuilder to trigger lazy load
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have constraints, the widget is being laid out = visible
        // Trigger lazy load on first visible build
        if (!_hasTriggeredLoad && _url == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _triggerLazyLoad());
        }
        
        // Show placeholder if not yet loaded
        if (_url == null && !_loading && !_error) {
          return _buildPlaceholder();
        }
        
        if (_loading) {
          return _buildLoadingIndicator();
        }

        if (_error || _url == null) {
          return _buildErrorPlaceholder();
        }

        return CachedNetworkImage(
          imageUrl: _url!,
          fit: BoxFit.cover,
          // Reduce memory usage with smaller cache
          memCacheWidth: 150,
          memCacheHeight: 180,
          placeholder: (context, url) => _buildLoadingIndicator(),
          errorWidget: (context, url, error) => _buildErrorPlaceholder(),
        );
      },
    );
  }
  
  Widget _buildPlaceholder() {
    // Simple colored placeholder with icon - no images loaded
    return Container(
      color: SofiStudioTheme.purple.withOpacity(0.25),
      child: Center(
        child: Icon(
          Icons.checkroom,
          color: Colors.white.withOpacity(0.4),
          size: 28,
        ),
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      color: SofiStudioTheme.purple.withOpacity(0.2),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorPlaceholder() {
    return Container(
      color: SofiStudioTheme.purple.withOpacity(0.3),
      child: const Icon(
        Icons.checkroom,
        color: Colors.white54,
        size: 32,
      ),
    );
  }
}

/// Widget to load doll images from Firebase Storage.
/// 
/// LAZY LOADING: Shows placeholder until visible, then loads.
class _DollFirebaseImage extends StatefulWidget {
  final String path;
  final Map<String, String> urlCache;

  const _DollFirebaseImage({
    required this.path,
    required this.urlCache,
  });

  @override
  State<_DollFirebaseImage> createState() => _DollFirebaseImageState();
}

class _DollFirebaseImageState extends State<_DollFirebaseImage> {
  String? _url;
  bool _loading = false;
  bool _hasTriggeredLoad = false;

  @override
  void initState() {
    super.initState();
    // Check cache immediately
    if (widget.urlCache.containsKey(widget.path)) {
      _url = widget.urlCache[widget.path];
    }
  }

  @override
  void didUpdateWidget(_DollFirebaseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _hasTriggeredLoad = false;
      _url = widget.urlCache.containsKey(widget.path) 
          ? widget.urlCache[widget.path] 
          : null;
      _loading = false;
    }
  }

  void _triggerLazyLoad() {
    if (_hasTriggeredLoad || _url != null) return;
    _hasTriggeredLoad = true;
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Check cache first
    if (widget.urlCache.containsKey(widget.path)) {
      if (mounted) {
        setState(() {
          _url = widget.urlCache[widget.path];
          _loading = false;
        });
      }
      return;
    }
    
    if (mounted) setState(() => _loading = true);
    try {
      final url = await StorageService.instance.getDownloadUrlSafe(widget.path);
      if (mounted) {
        if (url != null) {
          widget.urlCache[widget.path] = url;
          setState(() => _url = url);
        }
      }
    } catch (e) {
      debugPrint('[DollThumb] ❌ Failed to load ${widget.path}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Trigger lazy load when visible
        if (!_hasTriggeredLoad && _url == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _triggerLazyLoad());
        }
        
        // Placeholder state
        if (_url == null && !_loading) {
          return Container(
            color: SofiStudioTheme.purple.withOpacity(0.25),
            child: Icon(Icons.person, size: 20, color: Colors.white.withOpacity(0.4)),
          );
        }
        
        if (_loading) {
          return Container(
            color: SofiStudioTheme.purple.withOpacity(0.2),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            ),
          );
        }
        
        if (_url == null) {
          return Container(
            color: SofiStudioTheme.purple.withOpacity(0.3),
            child: const Icon(Icons.person, size: 24, color: Colors.white54),
          );
        }
        
        return CachedNetworkImage(
          imageUrl: _url!,
          fit: BoxFit.cover,
          memCacheWidth: 80, // Small cache size for thumbnails
          memCacheHeight: 100,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => Container(
            color: SofiStudioTheme.purple.withOpacity(0.2),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: SofiStudioTheme.purple.withOpacity(0.3),
            child: const Icon(Icons.person, size: 24, color: Colors.white54),
          ),
        );
      },
    );
  }
}
