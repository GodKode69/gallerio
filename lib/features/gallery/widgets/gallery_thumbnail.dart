import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class GalleryThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isFavorite;
  final bool showSelection;
  final bool enableHero;
  final double? size;

  const GalleryThumbnail({
    super.key,
    required this.asset,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isFavorite = false,
    this.showSelection = false,
    this.enableHero = true,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = AssetEntityImage(
      asset,
      isOriginal: false,
      thumbnailSize: ThumbnailSize(
        (asset.width * 0.1).round().clamp(200, 800),
        (asset.height * 0.1).round().clamp(200, 800),
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[900],
          child: const Icon(Icons.broken_image, color: Colors.white24),
        );
      },
    );

    image = _FadeInImage(child: image);

    if (enableHero) {
      image = Hero(
        tag: 'gallery-thumb-${asset.id}',
        child: image,
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (asset.type == AssetType.video)
              Positioned(
                bottom: 4,
                left: 4,
                child: _VideoBadge(duration: asset.videoDuration),
              ),
            if (isFavorite)
              const Positioned(
                top: 4,
                right: 4,
                child: _FavoriteBadge(),
              ),
            if (showSelection)
              Positioned(
                top: 4,
                left: 4,
                child: _SelectionBadge(isSelected: isSelected),
              ),
            if (showSelection && isSelected)
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
}

class _FadeInImage extends StatefulWidget {
  final Widget child;
  const _FadeInImage({required this.child});

  @override
  State<_FadeInImage> createState() => _FadeInImageState();
}

class _FadeInImageState extends State<_FadeInImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
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
        color: Colors.redAccent,
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
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}
