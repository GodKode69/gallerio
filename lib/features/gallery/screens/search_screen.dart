import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/gallery_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../app/shell_screen.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/gallery_thumbnail.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedFilter = 'all';
  Timer? _debounceTimer;
  List<AssetEntity> _searchResults = [];
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    searchFocusTrigger.addListener(_onFocusTrigger);
  }

  @override
  void dispose() {
    searchFocusTrigger.removeListener(_onFocusTrigger);
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusTrigger() {
    _focusNode.requestFocus();
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      AssetType? typeFilter;
      if (_selectedFilter == 'photos') typeFilter = AssetType.image;
      if (_selectedFilter == 'videos') typeFilter = AssetType.video;

      final results = ref
          .read(galleryProvider.notifier)
          .searchAssets(query, typeFilter: typeFilter);

      setState(() {
        _searchResults = results;
      });
    });
  }

  void _onSubmitted(String value) async {
    final authState = ref.read(authStateProvider);
    if (authState.isVaultEnabled && authState.hasVaultCode) {
      final verified = await ref
          .read(authStateProvider.notifier)
          .verifyVaultCode(value);
      if (verified && mounted) {
        _controller.clear();
        setState(() {});
        context.push('/vault');
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentlyViewed = ref.watch(
      galleryProvider.select((s) => s.recentlyViewed),
    );
    final isLoading = ref.watch(
      galleryProvider.select((s) => s.isLoading),
    );
    final query = _controller.text;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.chipBackground.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search photos...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _performSearch,
            onSubmitted: _onSubmitted,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _searchResults = [];
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: query.isEmpty
                ? _showFavoritesOnly
                    ? _buildFavoritesSection()
                    : _buildRecentlyViewedSection(recentlyViewed)
                : isLoading && _searchResults.isEmpty
                    ? const ShimmerSearchLoading()
                    : _searchResults.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off,
                            message: 'No results',
                          )
                        : _buildResultsGrid(_searchResults),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildChip('All', 'all'),
          const SizedBox(width: 8),
          _buildChip('Photos', 'photos'),
          const SizedBox(width: 8),
          _buildChip('Videos', 'videos'),
          const Spacer(),
          _buildFavoritesToggle(),
        ],
      ),
    );
  }

  Widget _buildFavoritesToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _showFavoritesOnly = !_showFavoritesOnly);
        ref
            .read(galleryProvider.notifier)
            .setShowFavoritesOnly(_showFavoritesOnly);
        if (_controller.text.isNotEmpty) {
          _performSearch(_controller.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _showFavoritesOnly
              ? AppColors.favoriteRed.withValues(alpha: 0.8)
              : AppColors.textPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: AppColors.textPrimary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Favorites',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: _showFavoritesOnly
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        if (_controller.text.isNotEmpty) {
          _performSearch(_controller.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedSection(List<AssetEntity> recentlyViewed) {
    if (recentlyViewed.isEmpty) {
      return Center(
        child: Text(
          'Type to search your photos',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 15,
          ),
        ),
      );
    }

    final rows = <List<AssetEntity>>[];
    for (int i = 0; i < recentlyViewed.length; i += 3) {
      rows.add(recentlyViewed.sublist(
        i,
        i + 3 > recentlyViewed.length ? recentlyViewed.length : i + 3,
      ));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Text(
            'Recently Viewed',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: i < row.length
                        ? GestureDetector(
                            onTap: () {
                              ref
                                  .read(galleryProvider.notifier)
                                  .addToRecentlyViewed(row[i]);
                              final flatIndex = recentlyViewed.indexOf(row[i]);
                              context.push('/viewer', extra: {
                                'assetId': row[i].id,
                                'title': row[i].title ?? 'Photo',
                                'assetIds': recentlyViewed.map((a) => a.id).toList(),
                                'initialIndex': flatIndex >= 0 ? flatIndex : 0,
                              });
                            },
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: GalleryThumbnail(
                                asset: row[i],
                                thumbnailSize: const ThumbnailSize.square(200),
                                enableHero: true,
                                onTap: () {
                                  ref
                                      .read(galleryProvider.notifier)
                                      .addToRecentlyViewed(row[i]);
                                  final flatIndex = recentlyViewed.indexOf(row[i]);
                                  context.push('/viewer', extra: {
                                    'assetId': row[i].id,
                                    'title': row[i].title ?? 'Photo',
                                    'assetIds': recentlyViewed.map((a) => a.id).toList(),
                                    'initialIndex': flatIndex >= 0 ? flatIndex : 0,
                                  });
                                },
                              ),
                            ),
                          )
                        : const SizedBox(height: 1),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFavoritesSection() {
    final favoriteIds = ref.watch(
      galleryProvider.select((s) => s.favoriteIds),
    );
    final assets = ref.watch(
      galleryProvider.select((s) => s.assets),
    );

    final favAssets =
        assets.where((a) => favoriteIds.contains(a.id)).toList();

    if (favAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border,
                size: 64,
                color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return _buildResultsGrid(favAssets);
  }

  Widget _buildResultsGrid(List<AssetEntity> results) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final asset = results[index];
        return GalleryThumbnail(
          asset: asset,
          thumbnailSize: const ThumbnailSize.square(200),
          isFavorite: ref.read(galleryProvider).favoriteIds.contains(asset.id),
          enableHero: true,
          onTap: () {
            ref.read(galleryProvider.notifier).addToRecentlyViewed(asset);
            context.push('/viewer', extra: {
              'assetId': asset.id,
              'title': asset.title ?? 'Photo',
              'assetIds': results.map((a) => a.id).toList(),
              'initialIndex': index,
            });
          },
        );
      },
    );
  }
}
