import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/bemyforager_icon_only.png');
  final original = img.decodePng(file.readAsBytesSync())!;
  print('Original: ${original.width}x${original.height}');

  // Find bounding box of non-transparent pixels (alpha > 10 to ignore near-transparent noise)
  int left = original.width, top = original.height, right = 0, bottom = 0;
  for (int y = 0; y < original.height; y++) {
    for (int x = 0; x < original.width; x++) {
      if (original.getPixel(x, y).a > 10) {
        left = min(left, x);
        top = min(top, y);
        right = max(right, x);
        bottom = max(bottom, y);
      }
    }
  }

  if (left >= right || top >= bottom) {
    print('No non-transparent content found.');
    return;
  }

  print('Content bounds: ($left, $top) → ($right, $bottom)');

  final contentW = right - left + 1;
  final contentH = bottom - top + 1;
  final side = max(contentW, contentH);

  // Crop to content, then center in a square canvas
  final cropped = img.copyCrop(original, x: left, y: top, width: contentW, height: contentH);
  final square = img.Image(width: side, height: side);
  img.fill(square, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(square, cropped,
      dstX: (side - contentW) ~/ 2, dstY: (side - contentH) ~/ 2);

  file.writeAsBytesSync(img.encodePng(square));
  print('Saved: ${side}x${side}');
}
