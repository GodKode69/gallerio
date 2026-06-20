import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum ImageFormat {
  jpeg('JPEG', '.jpg'),
  png('PNG', '.png'),
  webp('WebP', '.webp'),
  gif('GIF', '.gif'),
  bmp('BMP', '.bmp'),
  tiff('TIFF', '.tiff');

  final String label;
  final String extension;
  const ImageFormat(this.label, this.extension);
}

class ConversionResult {
  final File file;
  final int originalSize;
  final int convertedSize;
  final ImageFormat sourceFormat;
  final ImageFormat targetFormat;

  const ConversionResult({
    required this.file,
    required this.originalSize,
    required this.convertedSize,
    required this.sourceFormat,
    required this.targetFormat,
  });

  double get compressionRatio =>
      originalSize > 0 ? (1 - convertedSize / originalSize) * 100 : 0;
}

class ImageConverterService {
  static const _nativeFormats = {
    ImageFormat.jpeg,
    ImageFormat.png,
    ImageFormat.webp,
  };

  static bool get usesNativeCodec => true;

  static ImageFormat? detectFormat(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => ImageFormat.jpeg,
      '.png' => ImageFormat.png,
      '.webp' => ImageFormat.webp,
      '.gif' => ImageFormat.gif,
      '.bmp' => ImageFormat.bmp,
      '.tiff' || '.tif' => ImageFormat.tiff,
      _ => null,
    };
  }

  static bool isLossy(ImageFormat format) =>
      format == ImageFormat.jpeg || format == ImageFormat.webp;

  static Future<ConversionResult> convert({
    required String inputPath,
    required ImageFormat targetFormat,
    int quality = 85,
  }) async {
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();
    final sourceFormat = detectFormat(inputPath) ?? ImageFormat.jpeg;

    final outputDir = await getApplicationDocumentsDirectory();
    final convertedDir = Directory(p.join(outputDir.path, 'converted'));
    if (!await convertedDir.exists()) {
      await convertedDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = p.join(
      convertedDir.path,
      'converted_$timestamp${targetFormat.extension}',
    );

    Uint8List? result;

    if (_nativeFormats.contains(targetFormat)) {
      result = await _convertNative(
        inputPath: inputPath,
        targetFormat: targetFormat,
        quality: quality,
      );
    }

    result ??= await _convertDart(
      inputPath: inputPath,
      targetFormat: targetFormat,
      quality: quality,
    );

    final outputFile = await File(outputPath).writeAsBytes(result);
    final convertedSize = await outputFile.length();

    return ConversionResult(
      file: outputFile,
      originalSize: originalSize,
      convertedSize: convertedSize,
      sourceFormat: sourceFormat,
      targetFormat: targetFormat,
    );
  }

  static Future<Uint8List?> _convertNative({
    required String inputPath,
    required ImageFormat targetFormat,
    required int quality,
  }) async {
    try {
      final compressFormat = switch (targetFormat) {
        ImageFormat.jpeg => CompressFormat.jpeg,
        ImageFormat.png => CompressFormat.png,
        ImageFormat.webp => CompressFormat.webp,
        _ => throw UnsupportedError('Native conversion not supported'),
      };

      final result = await FlutterImageCompress.compressWithFile(
        inputPath,
        quality: quality,
        format: compressFormat,
      );

      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _convertDart({
    required String inputPath,
    required ImageFormat targetFormat,
    required int quality,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    return Uint8List.fromList(
      switch (targetFormat) {
        ImageFormat.jpeg => img.encodeJpg(image, quality: quality),
        ImageFormat.png => img.encodePng(image),
        ImageFormat.gif => img.encodeGif(image),
        ImageFormat.bmp => img.encodeBmp(image),
        ImageFormat.tiff => img.encodeTiff(image),
        ImageFormat.webp => throw UnsupportedError('WebP encoding requires native codec'),
      },
    );
  }
}
