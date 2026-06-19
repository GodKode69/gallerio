import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/widgets/top_message.dart';

class WallpaperPreviewScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const WallpaperPreviewScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<WallpaperPreviewScreen> createState() => _WallpaperPreviewScreenState();
}

class _WallpaperPreviewScreenState extends State<WallpaperPreviewScreen>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.arqora.gallerio/open_file');

  final GlobalKey _repaintKey = GlobalKey();

  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  final Map<int, Offset> _pointers = {};
  bool _isScaling = false;
  double _initialPinchDistance = 0;

  String _target = 'both';
  bool _isSetting = false;

  late AnimationController _doubleTapController;
  Animation<double>? _doubleTapAnimation;

  static const _minScale = 1.0;
  static const _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _doubleTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _doubleTapController.addListener(_onDoubleTapTick);
  }

  @override
  void dispose() {
    _doubleTapController.removeListener(_onDoubleTapTick);
    _doubleTapController.dispose();
    super.dispose();
  }

  void _onDoubleTapTick() {
    if (_doubleTapAnimation != null && mounted) {
      setState(() {
        _scale = _doubleTapAnimation!.value;
        _offset = _clampOffset(_offset);
      });
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapController.stop();
    final target = _scale > 1.0 ? _minScale : 2.5;
    _doubleTapAnimation = Tween<double>(begin: _scale, end: target).animate(
      CurvedAnimation(parent: _doubleTapController, curve: Curves.easeOutCubic),
    );
    _doubleTapController.forward(from: 0.0);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _doubleTapController.stop();
      _isScaling = true;
      _baseScale = _scale;
      final pts = _pointers.values.toList();
      _initialPinchDistance = (pts[0] - pts[1]).distance;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    if (_isScaling && _pointers.length >= 2 && _initialPinchDistance > 0) {
      final pts = _pointers.values.toList();
      final currentDist = (pts[0] - pts[1]).distance;
      final newScale = (_baseScale * currentDist / _initialPinchDistance)
          .clamp(_minScale, _maxScale);
      setState(() {
        _scale = newScale;
        _offset = _clampOffset(_offset);
      });
    } else if (_pointers.length == 1 && _scale > 1.01) {
      setState(() {
        _offset += event.delta;
        _offset = _clampOffset(_offset);
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _isScaling = false;
    }
    if (_pointers.isEmpty && _scale <= 1.01) {
      setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });
    }
  }

  Offset _clampOffset(Offset offset) {
    if (_scale <= 1.0) return Offset.zero;
    final viewSize = MediaQuery.of(context).size;
    final maxDx = (viewSize.width * (_scale - 1)) / 2;
    final maxDy = (viewSize.height * (_scale - 1)) / 2;
    return Offset(
      offset.dx.clamp(-maxDx, maxDx),
      offset.dy.clamp(-maxDy, maxDy),
    );
  }

  Future<void> _setWallpaper() async {
    if (_isSetting) return;
    setState(() => _isSetting = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No render object');

      final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No byte data');

      final tempDir = await getApplicationSupportDirectory();
      final file = File('${tempDir.path}/wallpaper_crop.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await _channel.invokeMethod('setWallpaper', {
        'filePath': file.path,
        'target': _target,
      });

      if (mounted) {
        showTopMessage(context, 'Wallpaper set');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showTopMessage(context, 'Could not set wallpaper: $e');
      }
    } finally {
      if (mounted) setState(() => _isSetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: _onDoubleTapDown,
              child: RepaintBoundary(
                key: _repaintKey,
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(
                          _offset.dx, _offset.dy, 0.0, 1.0)
                      ..scaleByDouble(_scale, _scale, 1.0, 1.0),
                    child: SizedBox.expand(
                      child: Image.file(
                        File(widget.filePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Wallpaper Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                  stops: [0, 1],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTargetButton('Lock', 'lock', accentColor),
                      const SizedBox(width: 8),
                      _buildTargetButton('Home', 'home', accentColor),
                      const SizedBox(width: 8),
                      _buildTargetButton('Both', 'both', accentColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSetting ? null : _setWallpaper,
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        disabledBackgroundColor:
                            accentColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSetting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Set Wallpaper',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetButton(String label, String value, Color accentColor) {
    final selected = _target == value;
    return GestureDetector(
      onTap: () => setState(() => _target = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accentColor
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accentColor
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
