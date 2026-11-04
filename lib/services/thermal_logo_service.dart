import 'dart:typed_data';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Converts an uploaded business logo into printer-ready, monochrome artwork.
/// The original upload is never modified; callers persist this output separately.
class ThermalLogoService {
  ThermalLogoService._();

  static const int width58mm = 384;
  static const int width80mm = 576;

  static Uint8List convert(Uint8List originalBytes, {required int targetWidth}) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported or corrupted image. Use PNG, JPG, JPEG or WebP.');
    }

    // Normalize EXIF orientation before trimming or resizing.
    final oriented = img.bakeOrientation(decoded);

    // Printer output is at most 576 pixels wide. Downsample very large phone
    // photos before scanning pixels to avoid excessive memory use.
    const maxSourceDimension = 1600;
    final largestDimension = math.max(oriented.width, oriented.height);
    final processingImage = largestDimension > maxSourceDimension
        ? img.copyResize(
            oriented,
            width: (oriented.width * maxSourceDimension / largestDimension).round(),
            height: (oriented.height * maxSourceDimension / largestDimension).round(),
            interpolation: img.Interpolation.average,
          )
        : oriented;
    final grayscale = img.grayscale(processingImage);

    // Find the visible artwork bounds. Near-white and transparent pixels are
    // treated as whitespace so white/transparent padding is removed.
    var left = grayscale.width;
    var top = grayscale.height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        final alpha = pixel.a.toDouble();
        final luminance = pixel.r.toDouble();
        if (alpha > 8 && luminance < 247) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    if (right < left || bottom < top) {
      throw const FormatException('The selected logo appears to be blank.');
    }

    // Add a small quiet margin after removing excess whitespace.
    final content = img.copyCrop(
      grayscale,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    );
    final padding = (targetWidth * 0.025).round().clamp(4, 16).toInt();
    final availableWidth = targetWidth - padding * 2;
    final scale = (availableWidth / content.width)
        .clamp(0.0001, 1200 / content.height)
        .toDouble();
    final resizedWidth = (content.width * scale).round().clamp(1, availableWidth).toInt();
    final resizedHeight = (content.height * scale).round().clamp(1, 1200).toInt();
    final resized = img.copyResize(
      content,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.average,
    );

    // Floyd-Steinberg error diffusion creates a true 1-bit black/white image.
    final width = resized.width;
    final height = resized.height;
    final luminance = List<double>.generate(
      width * height,
      (index) {
        final pixel = resized.getPixel(index % width, index ~/ width);
        return pixel.r.toDouble();
      },
    );
    final output = img.Image(width: width, height: height, numChannels: 1);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        final oldValue = luminance[index].clamp(0.0, 255.0).toDouble();
        final newValue = oldValue < 160 ? 0.0 : 255.0;
        final error = oldValue - newValue;
        output.setPixelRgb(x, y, newValue.toInt(), newValue.toInt(), newValue.toInt());

        void distribute(int dx, int dy, double factor) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
            final next = ny * width + nx;
            luminance[next] = (luminance[next] + error * factor)
                .clamp(0.0, 255.0)
                .toDouble();
          }
        }

        distribute(1, 0, 7 / 16);
        distribute(-1, 1, 3 / 16);
        distribute(0, 1, 5 / 16);
        distribute(1, 1, 1 / 16);
      }
    }

    // PNG is a lossless container for the 1-bit-style monochrome raster.
    return Uint8List.fromList(img.encodePng(output, level: 9));
  }

  static Uint8List for58mm(Uint8List originalBytes) =>
      convert(originalBytes, targetWidth: width58mm);

  static Uint8List for80mm(Uint8List originalBytes) =>
      convert(originalBytes, targetWidth: width80mm);
}
