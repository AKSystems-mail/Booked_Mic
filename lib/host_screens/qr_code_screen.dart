// qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeScreen extends StatelessWidget {
  final String showId;

  const QRCodeScreen({super.key, required this.showId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code')),
      body: Center(
        child: QrImageView(
          data: showId,
          version: QrVersions.auto,
          size: 200.0,
        ),
      ),
    );
  }
}