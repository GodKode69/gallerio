import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'gallery_thumbnail.dart';

class GalleryGrid extends StatefulWidget {
  final List<AssetEntity> assets;
  final void Function(AssetEntity asset) onTap;
  final VoidCallback? onLoadMore;

  const GalleryGrid({
    super.key,
    required this.assets,
    required this.onTap,
    this.onLoadMore,
  });

  @override
  State<GalleryGrid> createState() => _GalleryGridState();
}

class _GalleryGridState extends State<GalleryGrid> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No photos found',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: widget.assets.length,
      itemBuilder: (context, index) {
        final asset = widget.assets[index];
        return GalleryThumbnail(
          asset: asset,
          onTap: () => widget.onTap(asset),
        );
      },
    );
  }
}
