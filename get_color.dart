import 'dart:io';
import 'dart:typed_data';

void main() async {
  final file = File('assets/images/logo.png');
  final bytes = await file.readAsBytes();
  print('Image size: ${bytes.length} bytes');
  // I can't easily decode PNG in raw Dart without the 'image' package.
}
