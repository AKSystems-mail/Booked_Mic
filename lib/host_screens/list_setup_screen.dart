// lib/host_screens/list_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // Import for date formatting

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

  // --- Add State for Date ---
  DateTime? _selectedDate;
  // --- End Add ---

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

  Future<void> _selectDate(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
         context: context,
         initialDate: _selectedDate ?? DateTime.now(),
         firstDate: DateTime.now().subtract(Duration(days: 1)), // Allow today onwards
         lastDate: DateTime.now().add(Duration(days: 365 * 2)), // Allow up to 2 years ahead
     );
     if (picked != null && picked != _selectedDate) {
         setState(() {
             _selectedDate = picked;
         });
     }
  }


  Future<void> _createList() async {
    // --- Add Date Validation ---
    if (_selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a date for the list.')));
       return;
    }
    // --- End Add ---

    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { /* ... error handling ... */ return; }

    setState(() { _isLoading = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      final Map<String, dynamic> listData = {
        'listName': _listNameController.text.trim(),
        'venueName': _venueNameController.text.trim(),
        // --- Add Date Field ---
        'date': Timestamp.fromDate(_selectedDate!), // Save selected date as Timestamp
        // --- End Add ---
        'numberOfSpots': numberOfSpots,
        'numberOfWaitlistSpots': numberOfWaitlistSpots,
        'numberOfBucketSpots': numberOfBucketSpots,
        'userId': user.uid,
        'createdAt': Timestamp.now(),
        'spots': {},
        'signedUpUserIds': [],
      };
      await FirebaseFirestore.instance.collection('Lists').add(listData);
      if (mounted) { /* ... success handling ... */
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CreatedListsScreen()));
      }
    } catch (e) { /* ... error handling ... */ }
    finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  // ... (_buildNumberTextField remains the same) ...
   Widget _buildNumberTextField({ required TextEditingController controller, required String label, }) { /* ... */ return TextFormField(/* ... */); }


  @override
  Widget build(BuildContext context) {
    final Color buttonColor = Colors.blue.shade600;

    return Scaffold(
      appBar: AppBar( /* ... AppBar setup ... */ ),
      body: Container(
        decoration: BoxDecoration( /* ... gradient ... */ ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // List Name
              FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _listNameController, decoration: InputDecoration(labelText: 'List Name', /* ... */), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter name':null)),
              const SizedBox(height: 16),
              // Venue Name
              FadeInDown(duration: const Duration(milliseconds: 600), child: TextFormField(controller: _venueNameController, decoration: InputDecoration(labelText: 'Venue Name', /* ... */), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter venue':null)),
              const SizedBox(height: 16),

              // --- Add Date Picker Tile ---
              FadeInDown(
                 duration: const Duration(milliseconds: 700),
                 child: Card( // Wrap in Card for similar styling
                    color: Colors.white.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0, // Match filled text field look
                    child: ListTile(
                       leading: Icon(Icons.calendar_today, color: Colors.grey.shade700),
                       title: Text('Show Date', style: TextStyle(color: Colors.grey.shade700)),
                       subtitle: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!), // Format date nicely
                          style: TextStyle(color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500),
                       ),
                       onTap: () => _selectDate(context),
                       trailing: Icon(Icons.arrow_drop_down),
                    ),
                 ),
              ),
              // --- End Date Picker ---

              const SizedBox(height: 24),
              // Spot Number Fields
              FadeInDown(duration: const Duration(milliseconds: 800), child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots')),
              const SizedBox(height: 16),
              FadeInDown(duration: const Duration(milliseconds: 900), child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots')),
              const SizedBox(height: 16),
              FadeInDown(duration: const Duration(milliseconds: 1000), child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots')),
              const SizedBox(height: 32),
              // Submit Button
              _isLoading ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElasticIn(duration: const Duration(milliseconds: 800), child: ElevatedButton(onPressed: _createList, style: ElevatedButton.styleFrom(/* ... */), child: const Text('Create List', style: TextStyle(fontSize: 18, color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }
}