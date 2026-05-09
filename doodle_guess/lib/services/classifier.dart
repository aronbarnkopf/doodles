import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ui';

class Classifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isLoaded = false;

  static const int inputSize = 28;
  static const int numClasses = 345;

  static const bool _invertInput = true;

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset('assets/model/model.tflite');

    final inputTensor  = _interpreter.getInputTensor(0);
    final outputTensor = _interpreter.getOutputTensor(0);
    print('Input shape: ${inputTensor.shape}');
    print('Input type : ${inputTensor.type}');
    print('Output shape: ${outputTensor.shape}');

    final labelsData = await rootBundle.loadString('assets/labels/labels.txt');
    _labels = labelsData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    _isLoaded = true;
    print('Classifier loaded. Labels: ${_labels.length}');
  }

  bool get isLoaded => _isLoaded;

  Future<Uint8List> preprocessImage(Uint8List imageBytes) async {
    final codec = await instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final fullImage = frame.image;
    final fullBytes = await fullImage.toByteData(format: ImageByteFormat.rawRgba);
    final pixels = fullBytes!.buffer.asUint8List();
    final w = fullImage.width;
    final h = fullImage.height;

    print('Captured image: ${w}x$h');

    int minX = w, minY = h, maxX = 0, maxY = 0;
    bool hasDrawing = false;
    const borderMargin = 4;

    for (int y = borderMargin; y < h - borderMargin; y++) {
      for (int x = borderMargin; x < w - borderMargin; x++) {
        final i = (y * w + x) * 4;
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final deviation = (255 - r) + (255 - g) + (255 - b);
        if (deviation > 60) {
          hasDrawing = true;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (!hasDrawing) {
      print('No drawing detected — returning blank input');
      return Uint8List(inputSize * inputSize * 4);
    }

    int bW = maxX - minX;
    int bH = maxY - minY;
    print('Raw bounding box: ($minX,$minY)→($maxX,$maxY)  ${bW}x$bH on ${w}x$h');

    if (bW > w * 0.85 || bH > h * 0.85) {
      print('Bbox too large, using full canvas');
      minX = 0; minY = 0; maxX = w - 1; maxY = h - 1;
      bW = w; bH = h;
    }

    final maxDim = bW > bH ? bW : bH;
    final pad = (maxDim * 0.05).round(); // tight padding
    final halfSize = (maxDim ~/ 2) + pad;

    final centerX = (minX + maxX) ~/ 2;
    final centerY = (minY + maxY) ~/ 2;

    final cropX = (centerX - halfSize).clamp(0, w - 1);
    final cropY = (centerY - halfSize).clamp(0, h - 1);
    final cropW = ((centerX + halfSize).clamp(0, w) - cropX).clamp(1, w);
    final cropH = ((centerY + halfSize).clamp(0, h) - cropY).clamp(1, h);

    print('Bbox crop: ($cropX,$cropY)  ${cropW}x$cropH');

    // ── Pad shorter dimension with white to make it square ────────────────
    final squareSize = cropW > cropH ? cropW : cropH;
    final offsetX = (squareSize - cropW) ~/ 2;
    final offsetY = (squareSize - cropH) ~/ 2;

    final squared = Uint8List(squareSize * squareSize * 4);
    // Fill with white
    for (int i = 0; i < squared.length; i += 4) {
      squared[i] = 255; squared[i+1] = 255; squared[i+2] = 255; squared[i+3] = 255;
    }
    // Copy crop into center of square
    for (int y = 0; y < cropH; y++) {
      for (int x = 0; x < cropW; x++) {
        final srcI = ((cropY + y) * w + (cropX + x)) * 4;
        final dstI = ((offsetY + y) * squareSize + (offsetX + x)) * 4;
        squared[dstI]     = pixels[srcI];
        squared[dstI + 1] = pixels[srcI + 1];
        squared[dstI + 2] = pixels[srcI + 2];
        squared[dstI + 3] = 255;
      }
    }

    // ── Resize square to 28×28 ────────────────────────────────────────────
    final resizeCodec = await instantiateImageCodec(
      await _rawRgbaToImage(squared, squareSize, squareSize),
      targetWidth: inputSize,
      targetHeight: inputSize,
    );
    final resizedFrame = await resizeCodec.getNextFrame();
    final resized = await resizedFrame.image.toByteData(format: ImageByteFormat.rawRgba);
    return resized!.buffer.asUint8List();
  }

  Future<Uint8List> _rawRgbaToImage(Uint8List rgba, int width, int height) async {
    final completer = Completer<Uint8List>();
    decodeImageFromPixels(
      rgba, width, height, PixelFormat.rgba8888,
      (img) async {
        final png = await img.toByteData(format: ImageByteFormat.png);
        completer.complete(png!.buffer.asUint8List());
      },
    );
    return completer.future;
  }

  List<MapEntry<String, double>> classifyPixels(Uint8List pixels) {
    double minVal = 1.0, maxVal = 0.0, sum = 0.0;
    for (int idx = 0; idx < inputSize * inputSize; idx++) {
      final i = idx * 4;
      final brightness = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / (3.0 * 255.0);
      final val = _invertInput ? (1.0 - brightness) : brightness;
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
      sum += val;
    }
    final mean = sum / (inputSize * inputSize);
    print('Model input stats → min:${minVal.toStringAsFixed(3)} max:${maxVal.toStringAsFixed(3)} mean:${mean.toStringAsFixed(3)} (invertInput=$_invertInput)');

    final input = List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) {
          final i = (y * inputSize + x) * 4;
          final r = pixels[i];
          final g = pixels[i + 1];
          final b = pixels[i + 2];
          final brightness = (r + g + b) / (3.0 * 255.0);
          return [_invertInput ? (1.0 - brightness) : brightness];
        }),
      ),
    );

    final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);
    _interpreter.run(input, output);

    final scores = List<double>.from(output[0] as List);
    final results = List.generate(scores.length, (i) =>
      MapEntry(i < _labels.length ? _labels[i] : 'class_$i', scores[i]),
    );
    results.sort((a, b) => b.value.compareTo(a.value));

    return results.take(5).toList();
  }

  Future<void> debugPreprocess(Uint8List imageBytes) async {
    final pixels = await preprocessImage(imageBytes);
    final buf = StringBuffer('\n=== 28×28 model input (_invertInput=$_invertInput) ===\n');
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final i = (y * inputSize + x) * 4;
        final brightness = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / (3.0 * 255.0);
        final val = _invertInput ? (1.0 - brightness) : brightness;
        buf.write(val > 0.5 ? '#' : val > 0.2 ? '+' : '.');
      }
      buf.write('\n');
    }
    print(buf.toString());
  }
}