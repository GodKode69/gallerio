import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/widgets/top_message.dart';
import '../services/image_converter_service.dart';

class ImageConverterScreen extends StatefulWidget {
  const ImageConverterScreen({super.key});

  @override
  State<ImageConverterScreen> createState() => _ImageConverterScreenState();
}

class _ImageConverterScreenState extends State<ImageConverterScreen> {
  String? _inputPath;
  ImageFormat? _sourceFormat;
  int _sourceSize = 0;
  int _sourceWidth = 0;
  int _sourceHeight = 0;
  ImageFormat _targetFormat = ImageFormat.png;
  int _quality = 85;
  bool _isConverting = false;
  ConversionResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Converter'),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Start over',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_result != null) ..._buildResult(),
            if (_result == null) ..._buildConverter(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConverter() {
    return [
      if (_inputPath == null) ..._buildPickButton(),
      if (_inputPath != null) ..._buildSourceInfo(),
      if (_inputPath != null) ..._buildFormatPicker(),
      if (_inputPath != null && ImageConverterService.isLossy(_targetFormat))
        ..._buildQualitySlider(),
      if (_inputPath != null) ...[
        const SizedBox(height: 24),
        _buildConvertButton(),
      ],
    ];
  }

  List<Widget> _buildPickButton() {
    return [
      const SizedBox(height: 60),
      Icon(
        Icons.add_photo_alternate_outlined,
        size: 80,
        color: Colors.white.withValues(alpha: 0.15),
      ),
      const SizedBox(height: 16),
      Text(
        'Select an image to convert',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.photo_library),
        label: const Text('Pick from Gallery'),
      ),
    ];
  }

  List<Widget> _buildSourceInfo() {
    final formatLabel = _sourceFormat?.label ?? 'Unknown';
    final sizeLabel = _formatSize(_sourceSize);
    final dimsLabel = _sourceWidth > 0 && _sourceHeight > 0
        ? '$_sourceWidth x $_sourceHeight'
        : null;
    return [
      _buildImagePreview(File(_inputPath!)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _infoChip(label: formatLabel),
          const SizedBox(width: 8),
          _infoChip(label: sizeLabel),
          if (dimsLabel != null) ...[
            const SizedBox(width: 8),
            _infoChip(label: dimsLabel),
          ],
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _infoChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Widget> _buildFormatPicker() {
    return [
      Text(
        'Convert to',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ImageFormat.values.map((format) {
          final isSelected = format == _targetFormat;
          return GestureDetector(
            onTap: () => setState(() => _targetFormat = format),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                format.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _buildQualitySlider() {
    return [
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Quality',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_quality%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      Slider(
        value: _quality.toDouble(),
        min: 1,
        max: 100,
        divisions: 99,
        onChanged: (v) => setState(() => _quality = v.round()),
      ),
    ];
  }

  Widget _buildConvertButton() {
    return FilledButton(
      onPressed: _isConverting ? null : _convert,
      child: _isConverting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Convert'),
    );
  }

  List<Widget> _buildResult() {
    final result = _result!;
    final savedSmaller = result.convertedSize < result.originalSize;
    final ratio = result.compressionRatio.abs().toStringAsFixed(1);

    return [
      _buildImagePreview(result.file),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _infoChip(label: result.targetFormat.label),
          const SizedBox(width: 8),
          _infoChip(label: _formatSize(result.convertedSize)),
          const SizedBox(width: 8),
          _infoChip(
            label: savedSmaller ? '-$ratio%' : '+$ratio%',
          ),
        ],
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          '${_formatSize(result.originalSize)} → ${_formatSize(result.convertedSize)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _saveToGallery,
              icon: const Icon(Icons.save_alt),
              label: const Text('Save'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildImagePreview(File file) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    double previewHeight;
    if (_sourceWidth > 0 && _sourceHeight > 0) {
      final aspect = _sourceWidth / _sourceHeight;
      previewHeight = (screenWidth / aspect).clamp(100.0, 400.0);
    } else {
      previewHeight = 200;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: previewHeight,
        child: Image.file(
          file,
          width: double.infinity,
          height: previewHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            height: previewHeight,
            color: Colors.grey[900],
            child: const Icon(Icons.broken_image, color: Colors.white24, size: 48),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      final size = await File(path).length();
      final format = ImageConverterService.detectFormat(path);

      int width = 0;
      int height = 0;
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        width = frame.image.width;
        height = frame.image.height;
        frame.image.dispose();
      } catch (_) {}

      setState(() {
        _inputPath = path;
        _sourceFormat = format;
        _sourceSize = size;
        _sourceWidth = width;
        _sourceHeight = height;
        _result = null;
        if (format != null) {
          _targetFormat = ImageFormat.values.firstWhere(
            (f) => f != format,
            orElse: () => ImageFormat.png,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _convert() async {
    if (_inputPath == null) return;

    setState(() => _isConverting = true);

    try {
      final result = await ImageConverterService.convert(
        inputPath: _inputPath!,
        targetFormat: _targetFormat,
        quality: _quality,
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_result == null) return;

    try {
      final bytes = await _result!.file.readAsBytes();
      final oldName = p.basenameWithoutExtension(_inputPath!);
      final name = 'converted_$oldName';
      await PhotoManager.editor.saveImage(
        bytes,
        filename: '$name${_result!.targetFormat.extension}',
        title: name,
      );
      if (mounted) showTopMessage(context, 'Saved to gallery');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _share() async {
    if (_result == null) return;

    try {
      await Share.shareXFiles([XFile(_result!.file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _inputPath = null;
      _sourceFormat = null;
      _sourceSize = 0;
      _sourceWidth = 0;
      _sourceHeight = 0;
      _targetFormat = ImageFormat.png;
      _quality = 85;
      _isConverting = false;
      _result = null;
    });
  }
}
