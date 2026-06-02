// lib/services/web_download_helper_web.dart
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadFileWeb(Uint8List bytes, String fileName) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}
