// lib/host_screens/list_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for input formatters
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

// Import screen to navigate back to
import 'created_lists_screen.dart';

class ListSetupScreen extends StatefulWidget {
  const ListSetupScreen({Key? key}) : super(key: key);

  @override
  _ListSetupScreenState createState() => _ListSetupScreenState();
}

class _ListSetupScreenState extends State<ListSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  final _venueNameController = TextEditingController();
  final _spotsController = TextEditingController(text: '15');
  final _waitlistController = TextEditingController(text: '0');
  final _bucketController = TextEditingController(text: '0');
  // Optional: Controller for State field
  // final _stateController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _listNameController.dispose();
    _venueNameController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    // _stateController.dispose(); // Dispose if added
    super.dispose();
  }

  Future<void> _createList() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: You must be logged in.')));
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;
      // final String stateValue = _stateController.text.trim().toUpperCase();

      final Map<String, dynamic> listData = {
        'listName': _listNameController.text.trim(),
        'venueName': _venueNameController.text.trim(),
        'numberOfSpots': numberOfSpots,
        'numberOfWaitlistSpots': numberOfWaitlistSpots,
        'numberOfBucketSpots': numberOfBucketSpots,
        'userId': user.uid,
        'createdAt': Timestamp.now(),
        'spots': {},
        'signedUpUserIds': [],
        // if (stateValue.isNotEmpty) 'state': stateValue,
      };
      await FirebaseFirestore.instance.collection('Lists').add(listData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List created successfully!')));
        // Navigate back using pushReplacement to avoid stacking screens
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CreatedListsScreen()));
      }
    } catch (e) {
      print("Error creating list: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating list: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Helper for number input fields - Apply reference styling here
  Widget _buildNumberTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        // Apply reference style
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        // Remove focusedBorder if not desired with filled style
        // focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0)),
        counterText: "",
      ),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
      maxLength: 3,
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        final number = int.tryParse(value);
        if (number == null) return 'Please enter a valid number';
        if (number < 0) return 'Number cannot be negative';
        return null;
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // Using reference AppBar color
    final Color appBarColor = Colors.blue.shade400;
    // Using reference Button color
    final Color buttonColor = Colors.blue.shade600;

    return Scaffold(
      appBar: AppBar(
        // Use reference style
        backgroundColor: appBarColor,
        elevation: 0, // Remove shadow like reference
        foregroundColor: Colors.white, // Ensure icons/text are visible
        title: const Text('Setup New List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back using pushReplacement
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CreatedListsScreen()),
            );
          },
        ),
      ),
      // Apply gradient background from reference
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Apply FadeInDown animation and reference style
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: TextFormField(
                  controller: _listNameController,
                  decoration: InputDecoration(
                    labelText: 'List Name',
                    hintText: 'e.g., Tuesday Open Mic',
                    filled: true, // Reference style
                    fillColor: Colors.white.withOpacity(0.8), // Reference style
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Reference style
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a list name' : null,
                ),
              ),
              const SizedBox(height: 16),

              // Apply FadeInDown animation and reference style
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: TextFormField(
                  controller: _venueNameController,
                  decoration: InputDecoration(
                    labelText: 'Venue Name',
                    hintText: 'e.g., The Coffee House',
                    filled: true, // Reference style
                    fillColor: Colors.white.withOpacity(0.8), // Reference style
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Reference style
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a venue name' : null,
                ),
              ),
              const SizedBox(height: 16),

              // Optional: State Field with animation and style
              /*
              FadeInDown(
                duration: const Duration(milliseconds: 700),
                child: TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: 'State Abbreviation', hintText: 'e.g., CA (for search)',
                    filled: true, fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLength: 2, textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(height: 24),
              */
              const SizedBox(height: 24), // Adjust spacing if state field is added/removed

              // Apply FadeInDown animation to number fields
              FadeInDown(
                duration: const Duration(milliseconds: 800), // Adjust duration as needed
                child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots'),
              ),
              const SizedBox(height: 16),

              FadeInDown(
                duration: const Duration(milliseconds: 900), // Adjust duration
                child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots'),
              ),
              const SizedBox(height: 16),

              FadeInDown(
                duration: const Duration(milliseconds: 1000), // Adjust duration
                child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots'),
              ),
              const SizedBox(height: 32), // Space before the button

              // Apply ElasticIn animation and reference style to button
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: buttonColor)) // Use button color for consistency
                  : ElasticIn( // Apply animation from reference
                      duration: const Duration(milliseconds: 800),
                      child: ElevatedButton(
                        onPressed: _createList,
                        // Apply reference style
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16), // Reference padding
                          backgroundColor: buttonColor, // Reference color
                          foregroundColor: Colors.white, // Ensure text is white
                          shape: RoundedRectangleBorder( // Keep consistent button shape if desired, or remove for default
                             borderRadius: BorderRadius.circular(10.0) // Match input field radius
                          )
                        ),
                        child: const Text(
                          'Create List',
                          // Apply reference text style
                          style: TextStyle(fontSize: 18, color: Colors.white)
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}