import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../shared/widgets/top_message.dart';

class AlbumPickerResult {
  final AssetPathEntity album;
  final bool isMove;

  const AlbumPickerResult({required this.album, required this.isMove});
}

class AlbumPickerScreen extends StatefulWidget {
  final bool isMove;

  const AlbumPickerScreen({super.key, this.isMove = false});

  @override
  State<AlbumPickerScreen> createState() => _AlbumPickerScreenState();
}

class _AlbumPickerScreenState extends State<AlbumPickerScreen> {
  List<AssetPathEntity> _albums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );
      if (mounted) {
        setState(() {
          _albums = albums.where((a) => a.albumType == 1 && !a.isAll).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showTopMessage(context, 'Failed to load albums');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.isMove ? 'Move to album' : 'Copy to album',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                ..._albums.map((album) => _buildAlbumTile(album)),
                if (_albums.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No albums found',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAlbumTile(AssetPathEntity album) {
    return FutureBuilder<List<AssetEntity>>(
      future: album.getAssetListRange(start: 0, end: 1),
      builder: (context, snapshot) {
        final firstAsset = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;

        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 48,
              child: firstAsset != null
                  ? AssetEntityImage(
                      firstAsset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(96),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.folder, color: Colors.white24, size: 24),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.folder, color: Colors.white24, size: 24),
                    ),
            ),
          ),
          title: Text(
            album.name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: FutureBuilder<int>(
            future: album.assetCountAsync,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Text(
                '$count items',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              );
            },
          ),
          onTap: () {
            Navigator.of(context).pop(
              AlbumPickerResult(album: album, isMove: widget.isMove),
            );
          },
        );
      },
    );
  }
}
