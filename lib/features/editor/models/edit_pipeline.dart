import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'edit_session.dart';

class PipelineParams {
  final double sharpness, blur, vignette, gamma;
  final CropRect? cropRect;

  const PipelineParams({
    required this.sharpness,
    required this.blur,
    required this.vignette,
    required this.gamma,
    this.cropRect,
  });

  factory PipelineParams.fromSession(EditSession s) => PipelineParams(
    sharpness: s.sharpness,
    blur: s.blur,
    vignette: s.vignette,
    gamma: s.gamma,
    cropRect: s.cropRect,
  );
}

Uint8List runPipelineInBackground(Uint8List sourceBytes, PipelineParams params) {
  final source = img.decodeBmp(sourceBytes) ?? img.decodePng(sourceBytes);
  if (source == null) return sourceBytes;
  var image = source;

  if (params.cropRect != null) {
    final c = params.cropRect!;
    image = img.copyCrop(
      image,
      x: c.left.toInt().clamp(0, image.width - 1),
      y: c.top.toInt().clamp(0, image.height - 1),
      width: c.width.toInt().clamp(1, image.width),
      height: c.height.toInt().clamp(1, image.height),
    );
  }

  if (params.gamma != 0) {
    image = img.adjustColor(image, gamma: 1.0 - (params.gamma / 200));
  }

  if (params.sharpness > 0) {
    final amount = params.sharpness / 25.0;
    final blurred = img.gaussianBlur(img.Image.from(image), radius: 1);
    for (final p in image) {
      final b = blurred.getPixel(p.x, p.y);
      p.r = (p.r + amount * (p.r - b.r)).clamp(0, 255).toInt();
      p.g = (p.g + amount * (p.g - b.g)).clamp(0, 255).toInt();
      p.b = (p.b + amount * (p.b - b.b)).clamp(0, 255).toInt();
    }
  }

  if (params.blur > 0) {
    image = img.gaussianBlur(image, radius: (params.blur / 5).ceil().clamp(1, 20));
  }

  if (params.vignette > 0) {
    image = img.vignette(image, start: 0.15, end: 0.65,
        amount: (params.vignette / 100 * 1.5).clamp(0.0, 1.0));
  }

  return img.encodeBmp(image);
}

class EditPipeline {
  static img.Image apply(img.Image source, EditSession session, {bool skipGpu = false}) {
    if (session.isFlippedH) {
      source = img.copyFlip(source, direction: img.FlipDirection.horizontal);
    }
    if (session.isFlippedV) {
      source = img.copyFlip(source, direction: img.FlipDirection.vertical);
    }
    if (session.rotationDegrees != 0) {
      source = img.copyRotate(source, angle: session.rotationDegrees);
    }

    if (session.cropRect != null) {
      final c = session.cropRect!;
      source = img.copyCrop(
        source,
        x: c.left.toInt().clamp(0, source.width - 1),
        y: c.top.toInt().clamp(0, source.height - 1),
        width: c.width.toInt().clamp(1, source.width),
        height: c.height.toInt().clamp(1, source.height),
      );
    }

    if (!skipGpu) {
      if (session.brightness != 0 || session.contrast != 0 ||
          session.saturation != 0 || session.exposure != 0 ||
          session.hue != 0) {
        source = img.adjustColor(
          source,
          brightness: session.brightness == 0 ? null : 1.0 + (session.brightness / 100),
          contrast: session.contrast == 0 ? null : 1.0 + (session.contrast / 100),
          saturation: session.saturation == 0 ? null : 1.0 + (session.saturation / 100),
          exposure: session.exposure == 0 ? null : session.exposure / 100,
          hue: session.hue == 0 ? null : session.hue,
        );
      }

      if (session.warmth != 0) {
        final wf = session.warmth / 100;
        final rS = wf > 0 ? 1.0 + wf * 0.3 : 1.0;
        final bS = wf < 0 ? 1.0 + wf.abs() * 0.3 : 1.0;
        source = img.scaleRgba(
          source,
          scale: img.ColorRgb8(
            (rS * 255).clamp(0, 255).toInt(),
            255,
            (bS * 255).clamp(0, 255).toInt(),
          ),
        );
      }
    }

    if (session.gamma != 0) {
      source = img.adjustColor(
        source,
        gamma: 1.0 - (session.gamma / 200),
      );
    }

    if (session.sharpness > 0) {
      final amount = session.sharpness / 25.0;
      final blurred = img.gaussianBlur(img.Image.from(source), radius: 1);
      for (final p in source) {
        final b = blurred.getPixel(p.x, p.y);
        p.r = (p.r + amount * (p.r - b.r)).clamp(0, 255).toInt();
        p.g = (p.g + amount * (p.g - b.g)).clamp(0, 255).toInt();
        p.b = (p.b + amount * (p.b - b.b)).clamp(0, 255).toInt();
      }
    }

    if (session.blur > 0) {
      source = img.gaussianBlur(
        source,
        radius: (session.blur / 5).ceil().clamp(1, 20),
      );
    }

    if (session.vignette > 0) {
      source = img.vignette(
        source,
        start: 0.15,
        end: 0.65,
        amount: (session.vignette / 100 * 1.5).clamp(0.0, 1.0),
      );
    }

    return source;
  }
}

class FullPipelineParams {
  final double sharpness, blur, vignette, gamma;
  final double brightness, contrast, saturation, warmth, exposure, hue;
  final double rotationDegrees;
  final bool isFlippedH, isFlippedV;
  final CropRect? cropRect;

  const FullPipelineParams({
    required this.sharpness,
    required this.blur,
    required this.vignette,
    required this.gamma,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.warmth,
    required this.exposure,
    required this.hue,
    required this.rotationDegrees,
    required this.isFlippedH,
    required this.isFlippedV,
    this.cropRect,
  });

  factory FullPipelineParams.fromSession(EditSession s) => FullPipelineParams(
    sharpness: s.sharpness,
    blur: s.blur,
    vignette: s.vignette,
    gamma: s.gamma,
    brightness: s.brightness,
    contrast: s.contrast,
    saturation: s.saturation,
    warmth: s.warmth,
    exposure: s.exposure,
    hue: s.hue,
    rotationDegrees: s.rotationDegrees,
    isFlippedH: s.isFlippedH,
    isFlippedV: s.isFlippedV,
    cropRect: s.cropRect,
  );
}

Uint8List runFullSavePipeline(Uint8List sourceBytes, FullPipelineParams params) {
  final source = img.decodeBmp(sourceBytes) ?? img.decodeImage(sourceBytes);
  if (source == null) return sourceBytes;
  var image = source;

  if (params.isFlippedH) {
    image = img.copyFlip(image, direction: img.FlipDirection.horizontal);
  }
  if (params.isFlippedV) {
    image = img.copyFlip(image, direction: img.FlipDirection.vertical);
  }
  if (params.rotationDegrees != 0) {
    image = img.copyRotate(image, angle: params.rotationDegrees);
  }

  if (params.cropRect != null) {
    final c = params.cropRect!;
    image = img.copyCrop(
      image,
      x: c.left.toInt().clamp(0, image.width - 1),
      y: c.top.toInt().clamp(0, image.height - 1),
      width: c.width.toInt().clamp(1, image.width),
      height: c.height.toInt().clamp(1, image.height),
    );
  }

  if (params.brightness != 0 || params.contrast != 0 ||
      params.saturation != 0 || params.exposure != 0 ||
      params.hue != 0) {
    image = img.adjustColor(
      image,
      brightness: params.brightness == 0 ? null : 1.0 + (params.brightness / 100),
      contrast: params.contrast == 0 ? null : 1.0 + (params.contrast / 100),
      saturation: params.saturation == 0 ? null : 1.0 + (params.saturation / 100),
      exposure: params.exposure == 0 ? null : params.exposure / 100,
      hue: params.hue == 0 ? null : params.hue,
    );
  }

  if (params.warmth != 0) {
    final wf = params.warmth / 100;
    final rS = wf > 0 ? 1.0 + wf * 0.3 : 1.0;
    final bS = wf < 0 ? 1.0 + wf.abs() * 0.3 : 1.0;
    image = img.scaleRgba(
      image,
      scale: img.ColorRgb8(
        (rS * 255).clamp(0, 255).toInt(),
        255,
        (bS * 255).clamp(0, 255).toInt(),
      ),
    );
  }

  if (params.gamma != 0) {
    image = img.adjustColor(image, gamma: 1.0 - (params.gamma / 200));
  }

  if (params.sharpness > 0) {
    final amount = params.sharpness / 25.0;
    final blurred = img.gaussianBlur(img.Image.from(image), radius: 1);
    for (final p in image) {
      final b = blurred.getPixel(p.x, p.y);
      p.r = (p.r + amount * (p.r - b.r)).clamp(0, 255).toInt();
      p.g = (p.g + amount * (p.g - b.g)).clamp(0, 255).toInt();
      p.b = (p.b + amount * (p.b - b.b)).clamp(0, 255).toInt();
    }
  }

  if (params.blur > 0) {
    image = img.gaussianBlur(image, radius: (params.blur / 5).ceil().clamp(1, 20));
  }

  if (params.vignette > 0) {
    image = img.vignette(image, start: 0.15, end: 0.65,
        amount: (params.vignette / 100 * 1.5).clamp(0.0, 1.0));
  }

  return img.encodePng(image);
}
