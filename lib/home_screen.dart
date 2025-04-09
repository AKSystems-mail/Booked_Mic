// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'host_screens/list_setup_screen.dart';
import 'registration_screen.dart';
import 'performer_screens/performer_list_screen.dart'; // Added import


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    var screenSize = MediaQuery.of(context).size;
    // Define padding and spacing based on screen size
    var padding = screenSize.width * 0.1; // Example: 10% of screen width
    var buttonSpacing = screenSize.height * 0.02; // Example: 2% of screen height

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        backgroundColor: Colors.blueAccent, // Example color
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ListSetupScreen()),
                  );
                },
                child: const Text('Host Setup New List'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: buttonSpacing), // Responsive padding
                ),
              ),
              SizedBox(height: buttonSpacing), // Responsive spacing
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                  );
                },
                child: const Text('Register/Login'),
                 style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: buttonSpacing), // Responsive padding
                ),
              ),
              SizedBox(height: buttonSpacing), // Responsive spacing
              ElevatedButton(
                 onPressed: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => PerformerListScreen()), // Changed ScannerScreen to PerformerListScreen
                   );
                 },
                 child: const Text('Generate QR Code'), // Consider changing text to 'Scan QR Code'
                  style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: buttonSpacing), // Responsive padding
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
