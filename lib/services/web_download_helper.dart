// lib/services/web_download_helper.dart
import 'dart:typed_data';
import 'web_download_helper_stub.dart' if (dart.library.html) 'web_download_helper_web.dart' as helper;

void downloadFileWeb(Uint8List bytes, String fileName) {
  helper.downloadFileWeb(bytes, fileName);
}
