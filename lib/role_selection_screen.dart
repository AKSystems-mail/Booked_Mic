import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart'; // Import the animate_do package
import 'providers/bmic_app_state.dart';
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/registration_screen.dart'; // Import the registration screen

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade200],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Text(
                  'Select Your Role',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 5.0,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SlideInLeft(
                duration: const Duration(milliseconds: 1000),
                child: ElevatedButton(
                  onPressed: () {
                    Provider.of<BmicAppState>(context, listen: false).setRole('Host');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const CreatedListsScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    textStyle: const TextStyle(fontSize: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.blue.shade400,
                  ),
                  child: const Text('Host', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              SlideInRight(
                duration: const Duration(milliseconds: 1000),
                child: ElevatedButton(
                  onPressed: () {
                    Provider.of<BmicAppState>(context, listen: false).setRole('Performer');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    textStyle: const TextStyle(fontSize: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.purple.shade400,
                  ),
                  child: const Text('Performer', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}