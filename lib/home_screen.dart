// home_screen.dart
import 'package:flutter/material.dart';
import 'host_screens/list_setup_screen.dart';
import 'registration_screen.dart';
import 'host_screens/qr_code_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booked Mic')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListSetupScreen()),
                );
              },
              child: const Text('Setup Show'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                );
              },
              child: const Text('Register Performer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QRCodeScreen(showId: 'example_show_id')),
                );
              },
              child: const Text('Generate QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}