import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/top_message.dart';
import '../../editor/models/edit_session.dart';
import '../../editor/models/edit_pipeline.dart';

enum _EdgeHandle { topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right }

class ImageEditScreen extends StatefulWidget {
  final AssetEntity? asset;
  final String? filePath;
  final String title;

  const ImageEditScreen({
    super.key,
    this.asset,
    this.filePath,
    required this.title,
  });

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen>
    with SingleTickerProviderStateMixin {
  EditSession? _session;

  img.Image? _previewDecoded;
  Uint8List? _previewBytes;

  late AnimationController _transformAnim;
  double _prevRot = 0;
  double _targetRot = 0;
  bool _prevFlipH = false;
  bool _targetFlipH = false;
  bool _prevFlipV = false;
  bool _targetFlipV = false;

  double _cropScale = 1;
  double _cropOffsetX = 0;
  double _cropOffsetY = 0;
  double _cropMinScale = 1;
  double? _cropAspectRatio;
  bool _isPanning = false;
  double _panStartX = 0;
  double _panStartY = 0;
  double _panOffsetStartX = 0;
  double _panOffsetStartY = 0;
  double _pinchStartScale = 1;
  double _pinchStartOffsetX = 0;
  double _pinchStartOffsetY = 0;
  late AnimationController _snapBackAnim;
  double _snapFromX = 0;
  double _snapFromY = 0;
  double _snapToX = 0;
  double _snapToY = 0;
  Size _cropAvailSize = Size.zero;

  Rect? _cropBoxRect;
  _EdgeHandle? _resizeEdge;
  Rect? _resizeStartBox;
  Offset _resizeStartFocal = Offset.zero;

  String? _activeTool;
  String? _activeAdjustment;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isCropping = false;
  bool _isPreviewBusy = false;
  Timer? _previewDebounce;
  int _previewGeneration = 0;

  bool get _isVaultItem => widget.filePath != null;

  static const _adjustmentTools = [
    ('Brightness', 'brightness', Icons.brightness_6),
    ('Contrast', 'contrast', Icons.contrast),
    ('Saturation', 'saturation', Icons.water_drop),
    ('Warmth', 'warmth', Icons.wb_sunny),
    ('Exposure', 'exposure', Icons.exposure),
    ('Gamma', 'gamma', Icons.colorize),
    ('Hue', 'hue', Icons.palette),
    ('Sharpness', 'sharpness', Icons.auto_fix_high),
    ('Blur', 'blur', Icons.blur_on),
    ('Vignette', 'vignette', Icons.vignette),
    ('Filters', 'filters', Icons.auto_awesome),
  ];

  static const _presetNames = [
    'Original', 'Vivid', 'Warm', 'Cool', 'B&W', 'Vintage', 'Dramatic',
  ];

  static const _presetIcons = {
    'Original': Icons.filter_none,
    'Vivid': Icons.palette,
    'Warm': Icons.wb_sunny,
    'Cool': Icons.ac_unit,
    'B&W': Icons.contrast,
    'Vintage': Icons.filter_vintage,
    'Dramatic': Icons.flash_on,
  };

  @override
  void initState() {
    super.initState();
    _transformAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapBackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapBackAnim.addListener(() {
      if (_snapBackAnim.isAnimating) {
        final t = Curves.easeOutCubic.transform(_snapBackAnim.value);
        _cropOffsetX = ui.lerpDouble(_snapFromX, _snapToX, t)!;
        _cropOffsetY = ui.lerpDouble(_snapFromY, _snapToY, t)!;
        setState(() {});
      }
    });
    _loadImage();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _transformAnim.dispose();
    _snapBackAnim.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      File? sourceFile;
      if (_isVaultItem) {
        sourceFile = File(widget.filePath!);
      } else if (widget.asset != null) {
        sourceFile = await widget.asset!.file;
      }

      if (sourceFile == null || !await sourceFile.exists()) {
        if (mounted) {
          setState(() => _isLoading = false);
          showTopMessage(context, 'Could not load image');
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await sourceFile.copy(tempFile.path);

      final bytes = await tempFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          showTopMessage(context, 'Could not decode image');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _session = EditSession(
            originalFile: tempFile,
            originalDecoded: decoded,
            originalWidth: decoded.width,
            originalHeight: decoded.height,
          );
          _isLoading = false;
        });
        _cachePreview();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showTopMessage(context, 'Failed to load image');
      }
    }
  }

  void _cachePreview() {
    if (_session == null) return;
    const maxH = 800.0;
    double scale = 1.0;
    if (_session!.originalHeight > maxH) {
      scale = maxH / _session!.originalHeight;
    }
    final w = (_session!.originalWidth * scale).toInt();
    final h = (_session!.originalHeight * scale).toInt();
    _previewDecoded = img.copyResize(_session!.originalDecoded, width: w, height: h);
    _previewBytes = img.encodeBmp(_previewDecoded!);
  }

  bool get _hasCpuAdjustments =>
      _session != null &&
      (_session!.sharpness > 0 || _session!.blur > 0 ||
       _session!.vignette > 0 || _session!.gamma != 0);

  bool get _hasGpuAdjustments =>
      _session != null &&
      (_session!.brightness != 0 || _session!.contrast != 0 ||
       _session!.saturation != 0 || _session!.exposure != 0 ||
       _session!.warmth != 0 || _session!.hue != 0);

  void _onAdjustChanged() {
    setState(() {});

    if (_hasCpuAdjustments || _session?.hasCrop == true) {
      _isPreviewBusy = true;
      setState(() {});
      _previewDebounce?.cancel();
      _previewDebounce = Timer(const Duration(milliseconds: 50), _runPreviewUpdate);
    } else {
      _previewDebounce?.cancel();
      if (_previewDecoded != null) {
        _previewBytes = img.encodeBmp(_previewDecoded!);
      }
      _isPreviewBusy = false;
      setState(() {});
    }
  }

  Future<void> _runPreviewUpdate() async {
    if (_session == null || _previewDecoded == null) return;
    final gen = ++_previewGeneration;
    final params = PipelineParams.fromSession(_session!);
    final sourceBytes = img.encodeBmp(_previewDecoded!);
    try {
      final result = await Isolate.run(() => runPipelineInBackground(sourceBytes, params));
      if (gen != _previewGeneration) return;
      _previewBytes = result;
    } catch (_) {
      if (gen != _previewGeneration) return;
      _previewBytes = img.encodeBmp(_previewDecoded!);
    }
    _isPreviewBusy = false;
    if (mounted) setState(() {});
  }

  void _setAdjustValue(String key, double value) {
    if (_session == null) return;
    final minVal = EditSession.adjustMin(key);
    final maxVal = EditSession.adjustMax(key);
    final clamped = value.clamp(minVal, maxVal);
    final snapped = (clamped - minVal).abs() < 5 ? minVal : clamped;
    _session!.setAdjustValue(key, snapped);
    _onAdjustChanged();
  }

  void _resetAdjustment(String key) {
    if (_session == null) return;
    _session!.resetAdjustment(key);
    _onAdjustChanged();
  }

  void _resetAllAdjustments() {
    if (_session == null) return;
    _session!.resetAllAdjustments();
    _onAdjustChanged();
  }

  void _applyPreset(String name) {
    if (_session == null) return;
    final oldPreset = _session!.presetName;
    _session!.applyPreset(name);
    _session!.pushUndo(EditAction(type: 'preset', oldValue: oldPreset, newValue: name));
    _onAdjustChanged();
  }

  void _captureAnimState() {
    if (_transformAnim.isAnimating) {
      final t = Curves.easeOutCubic.transform(_transformAnim.value);
      _prevRot = ui.lerpDouble(_prevRot, _targetRot, t)!;
      _prevFlipH = ui.lerpDouble(_prevFlipH ? -1.0 : 1.0, _targetFlipH ? -1.0 : 1.0, t)! < 0;
      _prevFlipV = ui.lerpDouble(_prevFlipV ? -1.0 : 1.0, _targetFlipV ? -1.0 : 1.0, t)! < 0;
    } else {
      _prevRot = _targetRot;
      _prevFlipH = _targetFlipH;
      _prevFlipV = _targetFlipV;
    }
  }

  void _setRotation(int degrees) {
    if (_isProcessing || _isCropping || _session == null) return;
    _captureAnimState();
    final old = _session!.rotationDegrees;
    _session!.pushUndo(EditAction(type: 'rotation', oldValue: old, newValue: degrees.toDouble()));
    _session!.rotationDegrees = degrees.toDouble();
    _targetRot = degrees.toDouble();
    _transformAnim.forward(from: 0);
    setState(() {});
  }

  void _flipHorizontal() {
    if (_isProcessing || _isCropping || _session == null) return;
    _captureAnimState();
    final old = _session!.isFlippedH;
    _session!.pushUndo(EditAction(type: 'flipH', oldValue: old, newValue: !old));
    _session!.isFlippedH = !_session!.isFlippedH;
    _targetFlipH = _session!.isFlippedH;
    _transformAnim.forward(from: 0);
    setState(() {});
  }

  void _flipVertical() {
    if (_isProcessing || _isCropping || _session == null) return;
    _captureAnimState();
    final old = _session!.isFlippedV;
    _session!.pushUndo(EditAction(type: 'flipV', oldValue: old, newValue: !old));
    _session!.isFlippedV = !_session!.isFlippedV;
    _targetFlipV = _session!.isFlippedV;
    _transformAnim.forward(from: 0);
    setState(() {});
  }

  void _undo() {
    if (_session == null || !_session!.canUndo) return;
    _captureAnimState();
    _session!.undo();
    _targetRot = _session!.rotationDegrees;
    _targetFlipH = _session!.isFlippedH;
    _targetFlipV = _session!.isFlippedV;
    if (_targetRot != _prevRot || _targetFlipH != _prevFlipH || _targetFlipV != _prevFlipV) {
      _transformAnim.forward(from: 0);
    }
    _onAdjustChanged();
  }

  void _redo() {
    if (_session == null || !_session!.canRedo) return;
    _captureAnimState();
    _session!.redo();
    _targetRot = _session!.rotationDegrees;
    _targetFlipH = _session!.isFlippedH;
    _targetFlipV = _session!.isFlippedV;
    if (_targetRot != _prevRot || _targetFlipH != _prevFlipH || _targetFlipV != _prevFlipV) {
      _transformAnim.forward(from: 0);
    }
    _onAdjustChanged();
  }

  void _enterCrop() {
    if (_isProcessing || _isCropping || _session == null) return;
    _cropScale = 1;
    _cropOffsetX = 0;
    _cropOffsetY = 0;
    _cropAspectRatio = null;
    _cropBoxRect = null;
    setState(() {
      _isCropping = true;
      _activeTool = null;
      _activeAdjustment = null;
    });
  }

  void _cancelCrop() {
    setState(() {
      _isCropping = false;
      _activeTool = null;
      _cropScale = 1;
      _cropOffsetX = 0;
      _cropOffsetY = 0;
      _cropAspectRatio = null;
      _cropBoxRect = null;
    });
  }

  void _applyCrop(Size availSize) {
    if (_session == null) return;

    final cropBox = _cropBoxRect ?? _computeCropBox(availSize);
    final imgW = _session!.originalWidth.toDouble();
    final imgH = _session!.originalHeight.toDouble();
    final displayW = imgW * _cropScale;
    final displayH = imgH * _cropScale;

    final imgLeft = (availSize.width - displayW) / 2 + _cropOffsetX;
    final imgTop = (availSize.height - displayH) / 2 + _cropOffsetY;

    final scaleX = imgW / displayW;
    final scaleY = imgH / displayH;

    final cropLeft = ((cropBox.left - imgLeft) * scaleX).clamp(0.0, imgW);
    final cropTop = ((cropBox.top - imgTop) * scaleY).clamp(0.0, imgH);
    final cropRight = ((cropBox.right - imgLeft) * scaleX).clamp(0.0, imgW);
    final cropBottom = ((cropBox.bottom - imgTop) * scaleY).clamp(0.0, imgH);

    if (cropRight - cropLeft < 2 || cropBottom - cropTop < 2) {
      showTopMessage(context, 'Crop area too small');
      return;
    }

    final newCrop = CropRect(
      left: cropLeft,
      top: cropTop,
      right: cropRight,
      bottom: cropBottom,
    );

    _session!.pushUndo(EditAction(type: 'crop', oldValue: _session!.cropRect, newValue: newCrop));
    _session!.cropRect = newCrop;

    setState(() {
      _isCropping = false;
      _activeTool = null;
      _cropScale = 1;
      _cropOffsetX = 0;
      _cropOffsetY = 0;
      _cropAspectRatio = null;
    });
    _onAdjustChanged();
  }

  Future<void> _save() async {
    if (_session == null) return;
    setState(() => _isProcessing = true);

    try {
      final session = _session!;
      final fullParams = FullPipelineParams.fromSession(session);
      final sourceBytes = img.encodeBmp(img.Image.from(session.originalDecoded));

      final encoded = await Isolate.run(() => runFullSavePipeline(sourceBytes, fullParams));

      final name = widget.asset?.title ?? 'Edited_${DateTime.now().millisecondsSinceEpoch}';
      final baseName = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
      final fileName = '${baseName}_edited.png';

      final saveResult = await PhotoManager.editor.saveImage(encoded, filename: fileName);

      if (mounted) {
        showTopMessage(context, 'Saved as new image');
        Navigator.of(context).pop(saveResult.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showTopMessage(context, 'Save failed: $e');
      }
    }
  }

  String get _titleText {
    if (_isCropping) return 'Crop';
    if (_activeTool == 'rotate') return 'Rotate';
    if (_activeTool == 'flip') return 'Flip';
    if (_activeTool == 'adjust' && _activeAdjustment != null) {
      return _adjustmentTools.firstWhere((t) => t.$2 == _activeAdjustment).$1;
    }
    if (_activeTool == 'adjust') return 'Adjust';
    return 'Edit';
  }

  void _onBack() {
    if (_activeAdjustment != null) {
      setState(() => _activeAdjustment = null);
    } else if (_activeTool == 'adjust' || _activeTool == 'rotate' || _activeTool == 'flip') {
      setState(() => _activeTool = null);
    } else if (_isCropping) {
      _cancelCrop();
    } else {
      Navigator.of(context).pop();
    }
  }

  Float64List _buildGpuColorFilter() {
    final s = _session!;
    double brightness = s.brightness / 100;
    double contrast = s.contrast / 100;
    double saturation = s.saturation / 100;
    double exposure = s.exposure / 100;
    double warmth = s.warmth / 100;
    double hue = s.hue;

    double ex = pow(2.0, exposure).toDouble();

    double br = brightness * ex;
    double ct = 1.0 + contrast;
    double sa = 1.0 + saturation;

    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;

    double sr = (1.0 - sa) * lumR;
    double sg = (1.0 - sa) * lumG;
    double sb = (1.0 - sa) * lumB;

    double r1 = ct * (sr + sa) + 0.5 * (1.0 - ct);
    double r2 = ct * sg;
    double r3 = ct * sb;
    double g1 = ct * sr;
    double g2 = ct * (sg + sa) + 0.5 * (1.0 - ct);
    double g3 = ct * sb;
    double b1 = ct * sr;
    double b2 = ct * sg;
    double b3 = ct * (sb + sa) + 0.5 * (1.0 - ct);

    double wr = warmth > 0 ? 1.0 + warmth * 0.3 : 1.0;
    double wb = warmth < 0 ? 1.0 - warmth * 0.3 : 1.0;
    r1 *= wr; r2 *= wr; r3 *= wr;
    b1 *= wb; b2 *= wb; b3 *= wb;

    double rb = 1.0 + br;
    double gb = 1.0 + br;
    double bb = 1.0 + br;

    r1 *= rb; r2 *= rb; r3 *= rb;
    g1 *= gb; g2 *= gb; g3 *= gb;
    b1 *= bb; b2 *= bb; b3 *= bb;

    if (hue != 0) {
      final angle = hue * pi / 180.0;
      final cosA = cos(angle);
      final sinA = sin(angle);

      final iy = r1 * 0.299 + g1 * 0.587 + b1 * 0.114;
      final iq = r1 * 0.596 + g1 * (-0.274) + b1 * (-0.322);
      final ii = r1 * 0.211 + g1 * (-0.523) + b1 * 0.312;
      final jq = iq * cosA - ii * sinA;
      final iqq = iq * sinA + ii * cosA;
      r1 = iy + jq * 0.956 + iqq * 0.621;
      g1 = iy + jq * (-0.272) + iqq * (-0.647);
      b1 = iy + jq * (-1.105) + iqq * 1.702;

      final jy = r2 * 0.299 + g2 * 0.587 + b2 * 0.114;
      final jq2 = r2 * 0.596 + g2 * (-0.274) + b2 * (-0.322);
      final jiq = r2 * 0.211 + g2 * (-0.523) + b2 * 0.312;
      final jq2r = jq2 * cosA - jiq * sinA;
      final jiqq = jq2 * sinA + jiq * cosA;
      r2 = jy + jq2r * 0.956 + jiqq * 0.621;
      g2 = jy + jq2r * (-0.272) + jiqq * (-0.647);
      b2 = jy + jq2r * (-1.105) + jiqq * 1.702;

      final ky = r3 * 0.299 + g3 * 0.587 + b3 * 0.114;
      final kq = r3 * 0.596 + g3 * (-0.274) + b3 * (-0.322);
      final ki = r3 * 0.211 + g3 * (-0.523) + b3 * 0.312;
      final kqr = kq * cosA - ki * sinA;
      final kiq = kq * sinA + ki * cosA;
      r3 = ky + kqr * 0.956 + kiq * 0.621;
      g3 = ky + kqr * (-0.272) + kiq * (-0.647);
      b3 = ky + kqr * (-1.105) + kiq * 1.702;
    }

    const cta = 0.0;
    return Float64List.fromList([
      r1, g1, b1, 0, cta,
      r2, g2, b2, 0, cta,
      r3, g3, b3, 0, cta,
      0,  0,  0,  1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _onBack,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.undo,
                        color: _session?.canUndo == true
                            ? Colors.white
                            : Colors.white24,
                      ),
                      onPressed: _session?.canUndo == true ? _undo : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.redo,
                        color: _session?.canRedo == true
                            ? Colors.white
                            : Colors.white24,
                      ),
                      onPressed: _session?.canRedo == true ? _redo : null,
                    ),
                    Expanded(
                      child: (_session?.hasAnyChange ?? false)
                          ? GestureDetector(
                              onTap: _resetAllAdjustments,
                               child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.restart_alt, color: AppColors.favoriteRed, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reset',
                                    style: TextStyle(
                                      color: AppColors.favoriteRed,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              _titleText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    if (_isCropping)
                      TextButton(
                        onPressed: _isProcessing ? null : () {
                          _applyCrop(_cropAvailSize);
                        },
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            color: _isProcessing ? Colors.white24 : AppColors.favoriteRed,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _isProcessing ? null : _save,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: _isProcessing ? Colors.white24 : AppColors.favoriteRed,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _isCropping
                      ? _buildCropView()
                      : _previewBytes != null
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: AnimatedBuilder(
                                    animation: _transformAnim,
                                    builder: (context, child) {
                                      final t = Curves.easeOutCubic.transform(_transformAnim.value);
                                      final rot = ui.lerpDouble(_prevRot, _targetRot, t)!;
                                      final sx = ui.lerpDouble(
                                        _prevFlipH ? -1.0 : 1.0,
                                        _targetFlipH ? -1.0 : 1.0,
                                        t,
                                      )!;
                                      final sy = ui.lerpDouble(
                                        _prevFlipV ? -1.0 : 1.0,
                                        _targetFlipV ? -1.0 : 1.0,
                                        t,
                                      )!;

                                      return Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.diagonal3Values(sx, sy, 1.0)
                                          ..rotateZ(rot * pi / 180),
                                        child: child,
                                      );
                                    },
                                    child: _buildImageContent(),
                                  ),
                                ),
                                if (_isPreviewBusy)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.favoriteRed,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Processing...',
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            )
                          : const Center(
                              child: Icon(Icons.broken_image, color: Colors.white24, size: 64),
                            ),
            ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(AppColors.favoriteRed),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Container(
                  height: (_activeAdjustment != null && _activeAdjustment != 'filters') ? null : 64,
                  padding: _activeAdjustment != null && _activeAdjustment != 'filters'
                      ? const EdgeInsets.symmetric(vertical: 4)
                      : null,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _buildBottomBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    Widget imgWidget = Image.memory(
      _previewBytes!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (_hasGpuAdjustments) {
      imgWidget = ColorFiltered(
        colorFilter: ColorFilter.matrix(_buildGpuColorFilter()),
        child: imgWidget,
      );
    }

    return imgWidget;
  }

  // ──── CROP ────

  Rect _computeCropBox(Size availSize) {
    const padding = 24.0;
    final maxW = availSize.width - padding * 2;
    final maxH = availSize.height - padding * 2;

    if (_cropAspectRatio != null) {
      final ratio = _cropAspectRatio!;
      double w, h;
      if (maxW / ratio <= maxH) {
        w = maxW;
        h = maxW / ratio;
      } else {
        h = maxH;
        w = maxH * ratio;
      }
      return Rect.fromCenter(
        center: Offset(availSize.width / 2, availSize.height / 2),
        width: w,
        height: h,
      );
    }

    final w = maxW * 0.85;
    final h = maxH * 0.85;
    return Rect.fromCenter(
      center: Offset(availSize.width / 2, availSize.height / 2),
      width: w,
      height: h,
    );
  }

  Widget _buildCropView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_session == null) return const SizedBox.shrink();

        final availSize = Size(constraints.maxWidth, constraints.maxHeight);
        _cropAvailSize = availSize;

        _cropBoxRect ??= _computeCropBox(availSize);
        final cropBox = _cropBoxRect!;

        final imgW = _session!.originalWidth.toDouble();
        final imgH = _session!.originalHeight.toDouble();
        final fitScaleX = cropBox.width / imgW;
        final fitScaleY = cropBox.height / imgH;
        final minScale = max(fitScaleX, fitScaleY);
        _cropMinScale = minScale;

        if (_cropScale < minScale) {
          _cropScale = minScale;
        }

        final s = _cropScale;
        final displayW = imgW * s;
        final displayH = imgH * s;

        final imgLeft = (availSize.width - displayW) / 2 + _cropOffsetX;
        final imgTop = (availSize.height - displayH) / 2 + _cropOffsetY;
        final imageRect = Rect.fromLTWH(imgLeft, imgTop, displayW, displayH);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            _cropScale = minScale;
            _cropOffsetX = 0;
            _cropOffsetY = 0;
            setState(() {});
          },
          onScaleStart: (details) {
            if (details.pointerCount == 1) {
              final touch = details.focalPoint;
              final edge = _hitTestEdge(touch, cropBox);
              if (edge != null) {
                _resizeEdge = edge;
                _resizeStartBox = cropBox;
                _resizeStartFocal = touch;
              } else {
                _resizeEdge = null;
                _isPanning = true;
                _panStartX = details.focalPoint.dx;
                _panStartY = details.focalPoint.dy;
                _panOffsetStartX = _cropOffsetX;
                _panOffsetStartY = _cropOffsetY;
              }
            } else if (details.pointerCount == 2) {
              _resizeEdge = null;
              _isPanning = false;
              _pinchStartScale = s;
              _pinchStartOffsetX = _cropOffsetX;
              _pinchStartOffsetY = _cropOffsetY;
            }
          },
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount == 1) {
                if (_resizeEdge != null) {
                  _handleCropResize(details.focalPoint, availSize);
                } else if (_isPanning) {
                  _cropOffsetX = _panOffsetStartX + (details.focalPoint.dx - _panStartX);
                  _cropOffsetY = _panOffsetStartY + (details.focalPoint.dy - _panStartY);
                  _clampOffset(availSize, displayW, displayH);
                }
              } else if (details.pointerCount == 2) {
                final dx = details.focalPointDelta.dx;
                final dy = details.focalPointDelta.dy;

                final newScale = (_pinchStartScale * details.scale).clamp(_cropMinScale, 5.0);
                _cropScale = newScale;

                _cropOffsetX = _pinchStartOffsetX + dx;
                _cropOffsetY = _pinchStartOffsetY + dy;
                _clampOffset(availSize, imgW * _cropScale, imgH * _cropScale);
              }
            });
          },
          onScaleEnd: (_) {
            _isPanning = false;
            _resizeEdge = null;
            _snapIfNeeded(availSize, imgW * _cropScale, imgH * _cropScale);
          },
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: imageRect.left,
                  top: imageRect.top,
                  width: displayW,
                  height: displayH,
                  child: Image.memory(
                    _previewBytes!,
                    fit: BoxFit.fill,
                  ),
                ),
                CustomPaint(
                  size: availSize,
                  painter: _CropPainter(cropRect: cropBox),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _EdgeHandle? _hitTestEdge(Offset point, Rect box) {
    const hitSize = 30.0;
    const edgeHitSize = 24.0;

    if (_distanceToRect(point, box.topLeft) < hitSize) return _EdgeHandle.topLeft;
    if (_distanceToRect(point, box.topRight) < hitSize) return _EdgeHandle.topRight;
    if (_distanceToRect(point, box.bottomLeft) < hitSize) return _EdgeHandle.bottomLeft;
    if (_distanceToRect(point, box.bottomRight) < hitSize) return _EdgeHandle.bottomRight;

    final topEdge = Rect.fromLTRB(box.left + hitSize, box.top - edgeHitSize, box.right - hitSize, box.top + edgeHitSize);
    final bottomEdge = Rect.fromLTRB(box.left + hitSize, box.bottom - edgeHitSize, box.right - hitSize, box.bottom + edgeHitSize);
    final leftEdge = Rect.fromLTRB(box.left - edgeHitSize, box.top + hitSize, box.left + edgeHitSize, box.bottom - hitSize);
    final rightEdge = Rect.fromLTRB(box.right - edgeHitSize, box.top + hitSize, box.right + edgeHitSize, box.bottom - hitSize);

    if (topEdge.contains(point)) return _EdgeHandle.top;
    if (bottomEdge.contains(point)) return _EdgeHandle.bottom;
    if (leftEdge.contains(point)) return _EdgeHandle.left;
    if (rightEdge.contains(point)) return _EdgeHandle.right;

    return null;
  }

  double _distanceToRect(Offset point, Offset corner) {
    return (point - corner).distance;
  }

  void _handleCropResize(Offset focal, Size availSize) {
    if (_resizeEdge == null || _resizeStartBox == null) return;
    final start = _resizeStartBox!;
    final delta = focal - _resizeStartFocal;
    const minCropSize = 60.0;

    double left = start.left;
    double top = start.top;
    double right = start.right;
    double bottom = start.bottom;

    switch (_resizeEdge!) {
      case _EdgeHandle.topLeft:
        left = (start.left + delta.dx).clamp(0.0, right - minCropSize);
        top = (start.top + delta.dy).clamp(0.0, bottom - minCropSize);
        break;
      case _EdgeHandle.topRight:
        right = (start.right + delta.dx).clamp(left + minCropSize, availSize.width);
        top = (start.top + delta.dy).clamp(0.0, bottom - minCropSize);
        break;
      case _EdgeHandle.bottomLeft:
        left = (start.left + delta.dx).clamp(0.0, right - minCropSize);
        bottom = (start.bottom + delta.dy).clamp(top + minCropSize, availSize.height);
        break;
      case _EdgeHandle.bottomRight:
        right = (start.right + delta.dx).clamp(left + minCropSize, availSize.width);
        bottom = (start.bottom + delta.dy).clamp(top + minCropSize, availSize.height);
        break;
      case _EdgeHandle.top:
        top = (start.top + delta.dy).clamp(0.0, bottom - minCropSize);
        break;
      case _EdgeHandle.bottom:
        bottom = (start.bottom + delta.dy).clamp(top + minCropSize, availSize.height);
        break;
      case _EdgeHandle.left:
        left = (start.left + delta.dx).clamp(0.0, right - minCropSize);
        break;
      case _EdgeHandle.right:
        right = (start.right + delta.dx).clamp(left + minCropSize, availSize.width);
        break;
    }

    if (_cropAspectRatio != null) {
      final ratio = _cropAspectRatio!;
      final newW = right - left;
      final newH = bottom - top;
      final currentRatio = newW / newH;

      if ((currentRatio - ratio).abs() > 0.01) {
        if (_resizeEdge == _EdgeHandle.top || _resizeEdge == _EdgeHandle.bottom) {
          final clampedW = min(newH * ratio, availSize.width);
          final center = (left + right) / 2;
          left = (center - clampedW / 2).clamp(0.0, availSize.width - clampedW);
          right = left + clampedW;
        } else if (_resizeEdge == _EdgeHandle.left || _resizeEdge == _EdgeHandle.right) {
          final clampedH = min(newW / ratio, availSize.height);
          final center = (top + bottom) / 2;
          top = (center - clampedH / 2).clamp(0.0, availSize.height - clampedH);
          bottom = top + clampedH;
        } else {
          final targetH = newW / ratio;
          final targetW = newH * ratio;
          if (targetW > availSize.width) {
            final clampedH = newW / ratio;
            final center = (top + bottom) / 2;
            top = (center - clampedH / 2).clamp(0.0, availSize.height - clampedH);
            bottom = top + clampedH;
          } else if (targetH > availSize.height) {
            final clampedW = newH * ratio;
            final center = (left + right) / 2;
            left = (center - clampedW / 2).clamp(0.0, availSize.width - clampedW);
            right = left + clampedW;
          } else {
            if (_resizeEdge == _EdgeHandle.topLeft || _resizeEdge == _EdgeHandle.bottomLeft) {
              right = left + targetW;
              bottom = top + targetH;
            } else {
              left = right - targetW;
              bottom = top + targetH;
            }
          }
        }
      }
    }

    _cropBoxRect = Rect.fromLTRB(left, top, right, bottom);
  }

  void _clampOffset(Size availSize, double displayW, double displayH) {
    final halfDiffW = (displayW - availSize.width) / 2;
    final halfDiffH = (displayH - availSize.height) / 2;
    final maxX = max(0.0, halfDiffW + displayW * 0.1);
    final maxY = max(0.0, halfDiffH + displayH * 0.1);
    _cropOffsetX = _cropOffsetX.clamp(-maxX, maxX);
    _cropOffsetY = _cropOffsetY.clamp(-maxY, maxY);
  }

  void _snapIfNeeded(Size availSize, double displayW, double displayH) {
    final imgLeft = (availSize.width - displayW) / 2 + _cropOffsetX;
    final imgTop = (availSize.height - displayH) / 2 + _cropOffsetY;
    final imgRight = imgLeft + displayW;
    final imgBottom = imgTop + displayH;

    double targetX = _cropOffsetX;
    double targetY = _cropOffsetY;

    if (displayW > availSize.width) {
      if (imgLeft > 0) targetX = _cropOffsetX - imgLeft;
      if (imgRight < availSize.width) targetX = _cropOffsetX + (availSize.width - imgRight);
    } else {
      targetX = 0;
    }

    if (displayH > availSize.height) {
      if (imgTop > 0) targetY = _cropOffsetY - imgTop;
      if (imgBottom < availSize.height) targetY = _cropOffsetY + (availSize.height - imgBottom);
    } else {
      targetY = 0;
    }

    if ((targetX - _cropOffsetX).abs() > 0.5 || (targetY - _cropOffsetY).abs() > 0.5) {
      _snapFromX = _cropOffsetX;
      _snapFromY = _cropOffsetY;
      _snapToX = targetX;
      _snapToY = targetY;
      _snapBackAnim.forward(from: 0);
    }
  }

  // ──── BOTTOM BAR ────

  Widget _buildBottomBar() {
    if (_isCropping) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildRatioChip('Free', null),
          _buildRatioChip('1:1', 1.0),
          _buildRatioChip('4:3', 4 / 3),
          _buildRatioChip('3:4', 3 / 4),
          _buildRatioChip('16:9', 16 / 9),
          _buildRatioChip('9:16', 9 / 16),
        ],
      );
    }

    if (_activeAdjustment == 'filters') return _buildFiltersBar();
    if (_activeAdjustment != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAdjustActiveBar(),
          _buildAdjustmentSlider(),
        ],
      );
    }
    if (_activeTool == 'adjust') return _buildAdjustToolsList();
    if (_activeTool == 'rotate') return _buildRotateBar();
    if (_activeTool == 'flip') return _buildFlipBar();
    return _buildMainTools();
  }

  Widget _buildMainTools() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToolButton(icon: Icons.tune, label: 'Adjust', onTap: () => setState(() => _activeTool = 'adjust')),
        _buildToolButton(icon: Icons.crop, label: 'Crop', onTap: _enterCrop),
        _buildToolButton(icon: Icons.rotate_right, label: 'Rotate', onTap: () => setState(() => _activeTool = 'rotate')),
        _buildToolButton(icon: Icons.flip, label: 'Flip', onTap: () => setState(() => _activeTool = 'flip')),
      ],
    );
  }

  Widget _buildAdjustToolsList() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: _adjustmentTools.map((tool) {
        final key = tool.$2;
        final label = tool.$1;
        final icon = tool.$3;
        final isActive = _activeAdjustment == key;
        final hasChange = key != 'filters' && _session?.getAdjustValue(key) != 0;
        return GestureDetector(
          onTap: () => setState(() => _activeAdjustment = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 2),
                Icon(
                  icon,
                  color: isActive
                      ? AppColors.favoriteRed
                      : hasChange
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.favoriteRed
                        : hasChange
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: isActive || hasChange ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdjustActiveBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _resetAdjustment(_activeAdjustment!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.7), size: 22),
              const SizedBox(height: 4),
              Text('Reset', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRotateBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRotationOption(icon: Icons.rotate_right, label: '0\u00B0', flipH: true, isActive: _session?.rotationDegrees == 0, onTap: () => _setRotation(0)),
        _buildRotationOption(icon: Icons.rotate_right, label: '90\u00B0', isActive: _session?.rotationDegrees == 90, onTap: () => _setRotation(90)),
        _buildRotationOption(icon: Icons.rotate_left, label: '180\u00B0', flipH: true, isActive: _session?.rotationDegrees == 180, onTap: () => _setRotation(180)),
        _buildRotationOption(icon: Icons.rotate_left, label: '270\u00B0', isActive: _session?.rotationDegrees == 270, onTap: () => _setRotation(270)),
      ],
    );
  }

  Widget _buildFlipBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFlipOption(icon: Icons.flip, label: 'Horizontal', isActive: _session?.isFlippedH ?? false, onTap: _flipHorizontal),
        _buildFlipOption(icon: Icons.flip, label: 'Vertical', isActive: _session?.isFlippedV ?? false, onTap: _flipVertical, angle: pi / 2),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: _presetNames.map((name) {
        final icon = _presetIcons[name] ?? Icons.filter_none;
        final isActive = _session?.presetName == name || (name == 'Original' && _session?.presetName == null);
        return GestureDetector(
          onTap: () => _applyPreset(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.favoriteRed.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.2),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Icon(icon, color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.7), size: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdjustmentSlider() {
    final key = _activeAdjustment!;
    final maxVal = EditSession.adjustMax(key);
    final minVal = EditSession.adjustMin(key);
    final value = _session?.getAdjustValue(key) ?? 0;
    final tool = _adjustmentTools.firstWhere((t) => t.$2 == key);
    final icon = tool.$3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppColors.favoriteRed,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.favoriteRed.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: value.clamp(minVal, maxVal),
                    min: minVal,
                    max: maxVal,
                    onChanged: (v) => _setAdjustValue(key, v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  value.toInt().toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: value == minVal ? Colors.white.withValues(alpha: 0.4) : AppColors.favoriteRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _isProcessing ? Colors.white24 : Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: _isProcessing ? Colors.white24 : Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationOption({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool flipH = false,
  }) {
    Widget iconWidget = Icon(icon, color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.7), size: 20);
    if (flipH) {
      iconWidget = Transform.scale(scaleY: -1, child: iconWidget);
    }

    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppColors.favoriteRed.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.favoriteRed : Colors.transparent,
                  width: 2,
                ),
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlipOption({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    double angle = 0,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppColors.favoriteRed.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.favoriteRed : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Transform.rotate(
                angle: angle,
                child: Icon(icon, color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.7), size: 20),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioChip(String label, double? ratio) {
    final isSelected = _cropAspectRatio == ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _cropAspectRatio = ratio;
            _cropBoxRect = _computeCropBox(_cropAvailSize);
            _cropOffsetX = 0;
            _cropOffsetY = 0;
            _cropScale = 1;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.favoriteRed : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final Rect cropRect;

  _CropPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropRect.top), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, cropRect.bottom, size.width, size.height), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom), overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }

    final handlePaint = Paint()..color = Colors.white;
    const handleLen = 24.0;
    final handleStroke = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final corner in [cropRect.topLeft, cropRect.topRight, cropRect.bottomLeft, cropRect.bottomRight]) {
      canvas.drawRect(Rect.fromCenter(center: corner, width: 14, height: 14), handlePaint);
    }
    canvas.drawLine(cropRect.topLeft, Offset(cropRect.left + handleLen, cropRect.top), handleStroke);
    canvas.drawLine(cropRect.topLeft, Offset(cropRect.left, cropRect.top + handleLen), handleStroke);
    canvas.drawLine(cropRect.topRight, Offset(cropRect.right - handleLen, cropRect.top), handleStroke);
    canvas.drawLine(cropRect.topRight, Offset(cropRect.right, cropRect.top + handleLen), handleStroke);
    canvas.drawLine(cropRect.bottomLeft, Offset(cropRect.left + handleLen, cropRect.bottom), handleStroke);
    canvas.drawLine(cropRect.bottomLeft, Offset(cropRect.left, cropRect.bottom - handleLen), handleStroke);
    canvas.drawLine(cropRect.bottomRight, Offset(cropRect.right - handleLen, cropRect.bottom), handleStroke);
    canvas.drawLine(cropRect.bottomRight, Offset(cropRect.right, cropRect.bottom - handleLen), handleStroke);
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
