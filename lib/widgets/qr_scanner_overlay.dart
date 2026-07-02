import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QrScannerOverlay extends StatefulWidget {
  const QrScannerOverlay({super.key});

  @override
  State<QrScannerOverlay> createState() => _QrScannerOverlayState();
}

class _QrScannerOverlayState extends State<QrScannerOverlay> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  StreamSubscription<Barcode>? _subscription;
  bool _flashOn = false;

  @override
  void dispose() {
    _subscription?.cancel();
    controller?.pauseCamera();
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController c) {
    controller = c;
    c.resumeCamera();
    _subscription = c.scannedDataStream.listen((scanData) {
      if (scanData.code != null && mounted) {
        Navigator.pop(context, scanData.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan List QR Code'),
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            color: Colors.white,
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: _flashOn ? Colors.yellow : Colors.grey,
            ),
            iconSize: 32.0,
            onPressed: () {
              controller?.toggleFlash();
              setState(() => _flashOn = !_flashOn);
            },
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.camera_rear),
            iconSize: 32.0,
            onPressed: () => controller?.flipCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Center the QR code in the box',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
