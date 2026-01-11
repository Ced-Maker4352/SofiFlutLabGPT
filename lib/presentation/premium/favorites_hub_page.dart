import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sofi_test_connect/presentation/sofi_studio/favorites_manager.dart';
import 'package:sofi_test_connect/presentation/sofi_studio/models/favorite_outfit.dart';

class FavoritesHubPage extends StatefulWidget {
  const FavoritesHubPage({super.key});

  @override
  State<FavoritesHubPage> createState() => _FavoritesHubPageState();
}

class _FavoritesHubPageState extends State<FavoritesHubPage> {
  List<FavoriteOutfit> _favorites = [];
  bool _loading = true;
  bool _selectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final loaded = await FavoritesManager.load();
      // Sort newest first
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _favorites = loaded;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteFavorite(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Favorite?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _favorites.removeAt(index));
      await FavoritesManager.saveAll(_favorites);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Favorite removed'),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;
    
    final count = _selectedIndices.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count Favorites?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final idx in sortedIndices) {
        if (idx < _favorites.length) _favorites.removeAt(idx);
      }
      await FavoritesManager.saveAll(_favorites);
      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count favorites removed'),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _FavoritesGalleryView(
          favorites: _favorites,
          initialIndex: index,
          onDelete: (idx) async {
            setState(() => _favorites.removeAt(idx));
            await FavoritesManager.saveAll(_favorites);
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _selectionMode
            ? Text('${_selectedIndices.length} selected',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
            : const Text('Your Favorites',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _selectedIndices.isNotEmpty ? _deleteSelected : null,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedIndices.clear();
              }),
            ),
          ] else if (_favorites.isNotEmpty)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.checklist, color: Colors.white, size: 20),
              ),
              onPressed: () => setState(() => _selectionMode = true),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white54))
              : _favorites.isEmpty
                  ? _buildEmptyState()
                  : _buildGrid(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Favorites Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your favorite looks from the studio\nto see them here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Create Something'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe94560),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_favorites.length} saved',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_selectionMode)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIndices.length == _favorites.length) {
                        _selectedIndices.clear();
                      } else {
                        _selectedIndices.addAll(
                          List.generate(_favorites.length, (i) => i),
                        );
                      }
                    });
                  },
                  child: Text(
                    _selectedIndices.length == _favorites.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.7,
            ),
            itemCount: _favorites.length,
            itemBuilder: (context, index) => _FavoriteCard(
              favorite: _favorites[index],
              isSelected: _selectedIndices.contains(index),
              selectionMode: _selectionMode,
              onTap: () {
                if (_selectionMode) {
                  setState(() {
                    if (_selectedIndices.contains(index)) {
                      _selectedIndices.remove(index);
                    } else {
                      _selectedIndices.add(index);
                    }
                  });
                } else {
                  _openFullscreen(index);
                }
              },
              onLongPress: () {
                if (!_selectionMode) {
                  setState(() {
                    _selectionMode = true;
                    _selectedIndices.add(index);
                  });
                }
              },
              onDelete: () => _deleteFavorite(index),
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteOutfit favorite;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const _FavoriteCard({
    required this.favorite,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(favorite.timestamp);
    
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFe94560) : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 17 : 20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (favorite.imageUrl != null)
                Image.network(
                  favorite.imageUrl!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.broken_image, color: Colors.white24),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                    );
                  },
                )
              else if (favorite.imageBytes != null)
                Image.memory(
                  favorite.imageBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.image_not_supported, color: Colors.white24),
                ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Selection checkbox
              if (selectionMode)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFe94560)
                          : Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              // Date badge
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, color: Colors.white70, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!selectionMode)
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white70, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen gallery view with swipe navigation
class _FavoritesGalleryView extends StatefulWidget {
  final List<FavoriteOutfit> favorites;
  final int initialIndex;
  final Future<void> Function(int index) onDelete;

  const _FavoritesGalleryView({
    required this.favorites,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_FavoritesGalleryView> createState() => _FavoritesGalleryViewState();
}

class _FavoritesGalleryViewState extends State<_FavoritesGalleryView> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _extractTheme(String prompt) {
    // Try to extract theme info from prompt
    final patterns = ['style:', 'theme:', 'aesthetic:', 'look:'];
    for (final pattern in patterns) {
      final idx = prompt.toLowerCase().indexOf(pattern);
      if (idx != -1) {
        final start = idx + pattern.length;
        final end = prompt.indexOf(',', start);
        return prompt.substring(start, end > start ? end : null).trim();
      }
    }
    // Fallback: first 40 chars
    if (prompt.length > 40) return '${prompt.substring(0, 40)}...';
    return prompt.isNotEmpty ? prompt : 'Custom Style';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.favorites.isEmpty) {
      Navigator.pop(context);
      return const SizedBox.shrink();
    }

    final favorite = widget.favorites[_currentIndex];
    final dateStr = DateFormat('MMMM d, yyyy • h:mm a').format(favorite.timestamp);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showInfo = !_showInfo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image viewer with swipe
            PageView.builder(
              controller: _pageController,
              itemCount: widget.favorites.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: widget.favorites[index].imageUrl != null
                        ? Image.network(
                            widget.favorites[index].imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          )
                        : widget.favorites[index].imageBytes != null
                            ? Image.memory(
                                widget.favorites[index].imageBytes!,
                                fit: BoxFit.contain,
                              )
                            : const SizedBox.shrink(),
                  ),
                );
              },
            ),
            // Top bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showInfo ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${widget.favorites.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.grey[900],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Text('Delete?',
                                  style: TextStyle(color: Colors.white)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: Colors.white54)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await widget.onDelete(_currentIndex);
                            if (widget.favorites.isEmpty && mounted) {
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                if (_currentIndex >= widget.favorites.length) {
                                  _currentIndex = widget.favorites.length - 1;
                                }
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom info panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showInfo ? 0 : -150,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _extractTheme(favorite.prompt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
