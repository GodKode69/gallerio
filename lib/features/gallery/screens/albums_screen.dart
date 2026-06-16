import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/gallery_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/staggered_animation.dart';

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(
      galleryProvider.select((s) => s.hasPermission),
    );
    final albums = ref.watch(
      galleryProvider.select((s) => s.albums),
    );
    final isLoading = ref.watch(
      galleryProvider.select((s) => s.isLoading),
    );
    final favoriteIds = ref.watch(
      galleryProvider.select((s) => s.favoriteIds),
    );

    if (!hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Albums')),
        body: const Center(
          child: Text(
            'No gallery permission',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          if (favoriteIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () {
                ref.read(galleryProvider.notifier).setShowFavoritesOnly(true);
                context.go('/search');
              },
              tooltip: 'Favorites',
            ),
        ],
      ),
      body: albums.isEmpty
          ? isLoading
              ? const ShimmerAlbumLoading()
              : const Center(
                  child: Text(
                    'No albums found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return StaggeredAnimation(
                  index: index,
                  itemCount: albums.length,
                  child: AlbumCard(
                    key: ValueKey(album.id),
                    album: album,
                    onTap: () {
                      ref.read(galleryProvider.notifier).selectAlbum(album);
                      context.go('/gallery');
                    },
                  ),
                );
              },
            ),
    );
  }
}

class AlbumCard extends StatefulWidget {
  final AssetPathEntity album;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  late Future<List<AssetEntity>> _thumbnailFuture;
  late Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = widget.album.getAssetListPaged(page: 0, size: 4);
    _countFuture = widget.album.assetCountAsync;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnailGrid(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.album.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FutureBuilder<int>(
            future: _countFuture,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Text(
                '$count items',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid() {
    return FutureBuilder<List<AssetEntity>>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final assets = snapshot.data ?? [];
        if (assets.isEmpty) {
          return const Center(
            child: Icon(Icons.photo_library_outlined,
                color: Colors.white24, size: 40),
          );
        }

        if (assets.length == 1) {
          return AssetEntityImage(
            assets.first,
            isOriginal: false,
            thumbnailSize: const ThumbnailSize.square(200),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.grey[900]);
            },
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
          physics: const NeverScrollableScrollPhysics(),
          children: assets.map((asset) {
            return AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(200),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[900]);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
