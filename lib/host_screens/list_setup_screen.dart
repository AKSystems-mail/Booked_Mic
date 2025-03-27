// lib/pages/list_setup_screen.dart
// Renamed from create_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for input formatters
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Renamed class to match the filename convention
class ListSetupScreen extends StatefulWidget {
  // Updated constructor
  const ListSetupScreen({Key? key}) : super(key: key);

  @override
  // Updated state class name
  _ListSetupScreenState createState() => _ListSetupScreenState();
}

// Renamed state class
class _ListSetupScreenState extends State<ListSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  final _venueNameController = TextEditingController();
  final _spotsController = TextEditingController(text: '15'); // Default regular spots
  final _waitlistController = TextEditingController(text: '0'); // Default waitlist spots
  final _bucketController = TextEditingController(text: '0'); // Default bucket spots

  bool _isLoading = false;

  @override
  void dispose() {
    _listNameController.dispose();
    _venueNameController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    super.dispose();
  }

  Future<void> _createList() async {
    // Validate form inputs
    if (!_formKey.currentState!.validate()) {
      return; // If validation fails, do nothing
    }

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: You must be logged in to create a list.')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Parse spot numbers safely
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      // Prepare data for Firestore
      final Map<String, dynamic> listData = {
        'listName': _listNameController.text.trim(),
        'venueName': _venueNameController.text.trim(),
        'numberOfSpots': numberOfSpots,
        'numberOfWaitlistSpots': numberOfWaitlistSpots,
        'numberOfBucketSpots': numberOfBucketSpots,
        'userId': user.uid, // Store the ID of the user creating the list
        'createdAt': Timestamp.now(),
        'spots': {}, // Initialize with an EMPTY map for signups
      };

      // Add the document to the 'Lists' collection
      await FirebaseFirestore.instance.collection('Lists').add(listData);

      // Show success message and navigate back
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('List created successfully!')),
        );
        Navigator.pop(context); // Go back to the previous screen
      }

    } catch (e) {
      print("Error creating list: $e");
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating list: $e')),
        );
      }
    } finally {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  // Helper for number input fields
  Widget _buildNumberTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        counterText: "", // Hide the default counter
      ),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly // Allow only digits
      ],
      maxLength: 3, // Limit input length (e.g., max 999 spots)
      validator: (value) {
        if (value == null || value.isEmpty) {
          // Allow empty (defaults to 0), but could make it required if needed
          return null; // Treat empty as 0
        }
        final number = int.tryParse(value);
        if (number == null) {
          return 'Please enter a valid number';
        }
        if (number < 0) {
          return 'Number cannot be negative';
        }
        return null; // Input is valid
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup New List'), // Updated title
        // Match theme from signup_screen example
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Use ListView to prevent overflow on smaller screens
            children: <Widget>[
              // List Name Field
              TextFormField(
                controller: _listNameController,
                decoration: InputDecoration(
                  labelText: 'List Name',
                  hintText: 'e.g., Tuesday Open Mic',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a list name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),

              // Venue Name Field
              TextFormField(
                controller: _venueNameController,
                decoration: InputDecoration(
                  labelText: 'Venue Name',
                  hintText: 'e.g., The Coffee House',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a venue name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24.0), // Add more space before spot numbers

              // Spot Number Fields
              _buildNumberTextField(
                controller: _spotsController,
                label: 'Number of Regular Spots',
              ),
              SizedBox(height: 16.0),

              _buildNumberTextField(
                controller: _waitlistController,
                label: 'Number of Waitlist Spots',
              ),
              SizedBox(height: 16.0),

              _buildNumberTextField(
                controller: _bucketController,
                label: 'Number of Bucket Spots',
              ),
              SizedBox(height: 32.0), // Space before the button

              // Submit Button
              _isLoading
                  ? Center(child: CircularProgressIndicator()) // Show loading indicator
                  : ElevatedButton(
                      onPressed: _createList,
                      child: Text('Create List'),
                      style: ElevatedButton.styleFrom(
                        // Use primary color for button, match theme
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}