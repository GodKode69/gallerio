import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CropRect {
  final double left, top, right, bottom;

  const CropRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  Offset get center => Offset(left + width / 2, top + height / 2);

  CropRect copyWith({double? left, double? top, double? right, double? bottom}) {
    return CropRect(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  static CropRect full(int width, int height) {
    return CropRect(left: 0, top: 0, right: width.toDouble(), bottom: height.toDouble());
  }
}

class EditAction {
  final String type;
  final dynamic oldValue;
  final dynamic newValue;

  const EditAction({required this.type, this.oldValue, this.newValue});
}

class EditSession {
  final File originalFile;
  final img.Image originalDecoded;
  final int originalWidth;
  final int originalHeight;

  CropRect? cropRect;

  double rotationDegrees;
  bool isFlippedH;
  bool isFlippedV;

  double brightness;
  double contrast;
  double saturation;
  double warmth;
  double exposure;
  double gamma;
  double hue;
  double sharpness;
  double blur;
  double vignette;

  String? presetName;

  final List<EditAction> undoStack = [];
  final List<EditAction> redoStack = [];

  EditSession({
    required this.originalFile,
    required this.originalDecoded,
    required this.originalWidth,
    required this.originalHeight,
    this.cropRect,
    this.rotationDegrees = 0,
    this.isFlippedH = false,
    this.isFlippedV = false,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.exposure = 0,
    this.gamma = 0,
    this.hue = 0,
    this.sharpness = 0,
    this.blur = 0,
    this.vignette = 0,
  });

  bool get hasAdjustments =>
      brightness != 0 || contrast != 0 || saturation != 0 ||
      warmth != 0 || exposure != 0 || gamma != 0 ||
      hue != 0 || sharpness != 0 || blur != 0 || vignette != 0;

  bool get hasTransforms =>
      rotationDegrees != 0 || isFlippedH || isFlippedV;

  bool get hasCrop => cropRect != null;

  bool get hasAnyChange => hasAdjustments || hasTransforms || hasCrop;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  void pushUndo(EditAction action) {
    undoStack.add(action);
    redoStack.clear();
  }

  double getAdjustValue(String key) {
    switch (key) {
      case 'brightness': return brightness;
      case 'contrast': return contrast;
      case 'saturation': return saturation;
      case 'warmth': return warmth;
      case 'exposure': return exposure;
      case 'gamma': return gamma;
      case 'hue': return hue;
      case 'sharpness': return sharpness;
      case 'blur': return blur;
      case 'vignette': return vignette;
      default: return 0;
    }
  }

  void setAdjustValue(String key, double value) {
    final old = getAdjustValue(key);
    switch (key) {
      case 'brightness': brightness = value;
      case 'contrast': contrast = value;
      case 'saturation': saturation = value;
      case 'warmth': warmth = value;
      case 'exposure': exposure = value;
      case 'gamma': gamma = value;
      case 'hue': hue = value;
      case 'sharpness': sharpness = value;
      case 'blur': blur = value;
      case 'vignette': vignette = value;
    }
    pushUndo(EditAction(type: key, oldValue: old, newValue: value));
  }

  void resetAdjustment(String key) {
    final old = getAdjustValue(key);
    if (old != 0) {
      setAdjustValue(key, 0);
    }
  }

  void resetAllAdjustments() {
    final oldBrightness = brightness;
    final oldContrast = contrast;
    final oldSaturation = saturation;
    final oldWarmth = warmth;
    final oldExposure = exposure;
    final oldGamma = gamma;
    final oldHue = hue;
    final oldSharpness = sharpness;
    final oldBlur = blur;
    final oldVignette = vignette;
    final oldPreset = presetName;

    brightness = 0;
    contrast = 0;
    saturation = 0;
    warmth = 0;
    exposure = 0;
    gamma = 0;
    hue = 0;
    sharpness = 0;
    blur = 0;
    vignette = 0;
    presetName = null;

    final hasAny = oldBrightness != 0 || oldContrast != 0 || oldSaturation != 0 ||
        oldWarmth != 0 || oldExposure != 0 || oldGamma != 0 ||
        oldHue != 0 || oldSharpness != 0 || oldBlur != 0 || oldVignette != 0 ||
        oldPreset != null;
    if (hasAny) {
      pushUndo(EditAction(
        type: 'resetAll',
        oldValue: {
          'brightness': oldBrightness, 'contrast': oldContrast,
          'saturation': oldSaturation, 'warmth': oldWarmth,
          'exposure': oldExposure, 'gamma': oldGamma,
          'hue': oldHue, 'sharpness': oldSharpness,
          'blur': oldBlur, 'vignette': oldVignette,
          'preset': oldPreset,
        },
        newValue: null,
      ));
    }
  }

  bool undo() {
    if (undoStack.isEmpty) return false;
    final action = undoStack.removeLast();
    redoStack.add(action);
    _restoreAction(action, action.oldValue);
    return true;
  }

  bool redo() {
    if (redoStack.isEmpty) return false;
    final action = redoStack.removeLast();
    undoStack.add(action);
    _restoreAction(action, action.newValue);
    return true;
  }

  void _restoreAction(EditAction action, dynamic value) {
    switch (action.type) {
      case 'brightness': brightness = value as double;
      case 'contrast': contrast = value as double;
      case 'saturation': saturation = value as double;
      case 'warmth': warmth = value as double;
      case 'exposure': exposure = value as double;
      case 'gamma': gamma = value as double;
      case 'hue': hue = value as double;
      case 'sharpness': sharpness = value as double;
      case 'blur': blur = value as double;
      case 'vignette': vignette = value as double;
      case 'rotation': rotationDegrees = value as double;
      case 'flipH': isFlippedH = value as bool;
      case 'flipV': isFlippedV = value as bool;
      case 'crop': cropRect = value as CropRect?;
      case 'preset':
        resetAllAdjustments();
        if (value != null) applyPreset(value as String);
      case 'resetAll':
        if (value != null) {
          final v = value as Map<String, dynamic>;
          brightness = v['brightness'] as double;
          contrast = v['contrast'] as double;
          saturation = v['saturation'] as double;
          warmth = v['warmth'] as double;
          exposure = v['exposure'] as double;
          gamma = v['gamma'] as double;
          hue = v['hue'] as double;
          sharpness = v['sharpness'] as double;
          blur = v['blur'] as double;
          vignette = v['vignette'] as double;
          presetName = v['preset'] as String?;
        } else {
          brightness = 0;
          contrast = 0;
          saturation = 0;
          warmth = 0;
          exposure = 0;
          gamma = 0;
          hue = 0;
          sharpness = 0;
          blur = 0;
          vignette = 0;
          presetName = null;
        }
    }
  }

  static double adjustMax(String key) => key == 'hue' ? 180 : 100;

  static double adjustMin(String key) {
    switch (key) {
      case 'sharpness':
      case 'blur':
      case 'vignette':
      case 'gamma':
        return 0;
      default:
        return -100;
    }
  }

  static const presetValues = <String, Map<String, double>>{
    'Original': {},
    'Vivid': {'brightness': 5, 'contrast': 15, 'saturation': 30},
    'Warm': {'brightness': 3, 'saturation': 10, 'warmth': 40},
    'Cool': {'brightness': 3, 'saturation': 5, 'warmth': -40},
    'B&W': {'contrast': 10, 'saturation': -100},
    'Vintage': {
      'brightness': -5,
      'contrast': 10,
      'saturation': -20,
      'warmth': 20,
      'vignette': 30,
    },
    'Dramatic': {
      'brightness': -5,
      'contrast': 30,
      'saturation': -10,
      'vignette': 40,
    },
  };

  void applyPreset(String name) {
    final values = presetValues[name];
    if (values == null) return;
    brightness = values['brightness'] ?? 0;
    contrast = values['contrast'] ?? 0;
    saturation = values['saturation'] ?? 0;
    warmth = values['warmth'] ?? 0;
    exposure = values['exposure'] ?? 0;
    gamma = values['gamma'] ?? 0;
    hue = values['hue'] ?? 0;
    sharpness = values['sharpness'] ?? 0;
    blur = values['blur'] ?? 0;
    vignette = values['vignette'] ?? 0;
    presetName = name;
  }
}
