import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../app/theme.dart';
import '../../../core/cache/thumbnail_prefetcher.dart';

class GalleryThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isFavorite;
  final bool showSelection;
  final bool enableHero;
  final ThumbnailPrefetcher? prefetcher;
  final ThumbnailSize thumbnailSize;

  const GalleryThumbnail({
    super.key,
    required this.asset,
    required this.thumbnailSize,
    this.onTap,
    this.isSelected = false,
    this.isFavorite = false,
    this.showSelection = false,
    this.enableHero = true,
    this.prefetcher,
  });

  @override
  State<GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<GalleryThumbnail> {
  @override
  void initState() {
    super.initState();
    widget.prefetcher?.addListener(_onCacheChanged);
  }

  @override
  void didUpdateWidget(covariant GalleryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefetcher != widget.prefetcher) {
      oldWidget.prefetcher?.removeListener(_onCacheChanged);
      widget.prefetcher?.addListener(_onCacheChanged);
    }
  }

  @override
  void dispose() {
    widget.prefetcher?.removeListener(_onCacheChanged);
    super.dispose();
  }

  void _onCacheChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cached = widget.prefetcher?.getCachedThumbnail(widget.asset.id);

    Widget image;

    if (cached != null) {
      image = Image.memory(
        cached,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return _fallbackThumbnail();
        },
      );
    } else {
      image = _placeholderThumbnail();
    }

    if (widget.enableHero) {
      image = Hero(
        tag: 'gallery-thumb-${widget.asset.id}',
        child: image,
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (widget.asset.type == AssetType.video)
              Positioned(
                bottom: 4,
                left: 4,
                child: _VideoBadge(duration: widget.asset.videoDuration),
              ),
            if (widget.isFavorite)
              const Positioned(
                top: 4,
                right: 4,
                child: _FavoriteBadge(),
              ),
            if (widget.showSelection)
              Positioned(
                top: 4,
                left: 4,
                child: _SelectionBadge(isSelected: widget.isSelected),
              ),
            if (widget.showSelection && widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderThumbnail() {
    return Container(
      color: Colors.grey[900],
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.broken_image, color: Colors.white24),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  final Duration duration;
  const _VideoBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite,
        color: AppColors.favoriteRed,
        size: 14,
      ),
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  final bool isSelected;
  const _SelectionBadge({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}
